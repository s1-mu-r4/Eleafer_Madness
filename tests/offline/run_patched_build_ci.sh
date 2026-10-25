#!/usr/bin/env bash
# Controlled runner-side offline verification; no USB or firmware flashing.
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SOURCE_DATE_EPOCH=1792902672
RON7="08202453b54c2284df27c9f188f66c2b2fb0f92e"
BSP="61f8103bfe58ae8853affdba8a01dcc26e41079e"
EVIC="ef62fa601fd9b25d6261fdddf984cba462229b2b"
git clone --quiet https://github.com/wighawag/myevic.git "$TMP/ron7"
git clone --quiet https://github.com/OpenNuvoton/M451BSP.git "$TMP/bsp"
git clone --quiet https://github.com/ClockSelect/python-evic.git "$TMP/python-evic"
git -C "$TMP/ron7" checkout --quiet --detach "$RON7"
git -C "$TMP/bsp" checkout --quiet --detach "$BSP"
git -C "$TMP/python-evic" checkout --quiet --detach "$EVIC"
test "$(git -C "$TMP/ron7" rev-parse HEAD)" = "$RON7"
test "$(git -C "$TMP/bsp" rev-parse HEAD)" = "$BSP"
test "$(git -C "$TMP/python-evic" rev-parse HEAD)" = "$EVIC"

python3 tests/offline/validate_ron7_minimal_patch.py --checkout "$TMP/ron7"
export ELEAFER_RON7_SOURCE="$TMP/ron7"
PYTHONPATH="$ROOT/tests/offline" python3 -m unittest discover \
  -s tests/offline -p 'test_ron7_artifact_audit.py' -v
PYTHONPATH="$ROOT/tests/offline" python3 -m unittest discover \
  -s tests/offline -p 'test_e115_stock_zip_audit.py' -v
PYTHONPATH="$ROOT/tests/offline" python3 -m unittest discover \
  -s tests/offline -p 'test_ron7_native.py' -v

python3 -m venv "$TMP/venv"
"$TMP/venv/bin/python" -m pip install --no-input \
  binstruct==1.0.1 bitarray==3.12.3 click==8.5.0 pillow==13.0.0
mkdir -p "$TMP/tools" "$TMP/sdk" "$TMP/build1" "$TMP/build2"
ln -s "$TMP/bsp" "$TMP/sdk/nuvoton-sdk"
cat > "$TMP/tools/evic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec python3 -c 'from evic.cli import main; main()' "$@"
EOF
chmod +x "$TMP/tools/evic"
export PATH="$TMP/tools:$TMP/venv/bin:$PATH"
export PYTHONPATH="$TMP/python-evic"
export EVICSDK="$TMP/sdk" ARMGCC="/usr/lib"
printf 'LDFLAGS += -Map=bin/myevic.map\nCFLAGS += -fstack-usage\n' > "$TMP/map.mk"
for n in 1 2; do
  git -C "$TMP/ron7" archive "$RON7" | tar -x -C "$TMP/build$n"
  (
    cd "$TMP/build$n"
    git apply --check "$ROOT/patches/0001-isolate-usb-profile-stack-and-fix-rom-metadata.patch"
    git apply "$ROOT/patches/0001-isolate-usb-profile-stack-and-fix-rom-metadata.patch"
    git apply --check "$ROOT/patches/0002-harden-fmcread-validation.patch"
    git apply "$ROOT/patches/0002-harden-fmcread-validation.patch"
    python3 "$ROOT/tests/offline/validate_fmcread_guard.py" src/meusbd.c
    make clean
    make -f Makefile -f "$TMP/map.mk" -j2 all
  )
done
for filename in myevic.elf myevic_dec.bin myevic.bin; do
  cmp "$TMP/build1/bin/$filename" "$TMP/build2/bin/$filename"
  sha256sum "$TMP/build1/bin/$filename"
done

python3 tests/offline/ron7_artifact_audit.py \
  "$TMP/build1/bin/myevic.elf" "$TMP/build1/bin/myevic_dec.bin" > "$TMP/elf.json"

# Only offline invariants. No full runtime/interrupt-stack guarantee.
python3 - "$TMP" <<'PY'
import json
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
report = json.loads((root / "elf.json").read_text())
assert report["raw_matches_selected_sections"], "objcopy selected section mismatch"
assert report["initialization_matches_sections"], "RAM init table mismatch"
assert not report["load_lma_conflicts"], "ELF LOAD byte conflicts"
assert len((root/"build1/bin/myevic_dec.bin").read_bytes()) <= 102400, "ROM overflow"
s = report["sections"]
assert s[".sram"]["type"] == 8, ".sram must be SHT_NOBITS"
assert s[".raminit"]["size"] == 24, "Unexpected RAM init table size"
size = len((root/"build1/bin/myevic_dec.bin").read_bytes())
assert size == s[".raminit"]["lma"] + 24, "MSC firmware length != BIN end"
functions = {}
for su in (root/"build1").rglob("*.su"):
    for line in su.read_text(errors="replace").splitlines():
        m = re.search(r":([^:\t]+)\t(\d+)\t", line)
        if m:
            name = m.group(1)
            value = int(m.group(2))
            functions[name] = max(value, functions.get(name, 0))
            # GCC may append a .constprop / .isra specialization to a noinline function.
            if name.startswith("hidWriteStoredProfile."):
                functions["hidWriteStoredProfile"] = max(value, functions.get("hidWriteStoredProfile", 0))
print("Matching compiler .su names:", [k for k in functions if "Profile" in k or "hidGetOutReport" in k])
for fn in ("hidGetOutReport","SaveProfile","hidWriteStoredProfile"):
    assert fn in functions, "missing stack report: "+fn
a = functions["hidGetOutReport"] + functions["SaveProfile"]
b = functions["hidGetOutReport"] + functions["hidWriteStoredProfile"]
assert a < 4096 and b < 4096, "stack nested frame exceeds 4KiB"
print("PATCHED_OFFLINE_BUILD_CHECKS_PASS; NOT A FLASHING APPROVAL")
print("Stack frames:", {fn:functions[fn] for fn in ("hidGetOutReport","SaveProfile","hidWriteStoredProfile")})
print("Nested frame checks:", a, b)
print("ROM BIN bytes:", size)
print("ROM budget remaining:", 102400-size)
print("ELF LOAD conflicts:", report["load_lma_conflicts"])
print("Runtime ISR nesting and physical recovery: NOT VERIFIED")
PY
arm-none-eabi-readelf -lW "$TMP/build1/bin/myevic.elf" | sed -n '1,48p'
arm-none-eabi-size -A "$TMP/build1/bin/myevic.elf" | tail -25
echo "No device operation and no firmware artifact upload."
