#!/usr/bin/env python3
"""Rehearse the Ron7 patch in a temporary COPY, never on the provided checkout.
No USB, HID, firmware update, source-repo mutation, network, or device access.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

RON7_SHA = "08202453b54c2284df27c9f188f66c2b2fb0f92e"
FILES = ("src/meusbd.c", "src/myevic.s", "linker.ld")
DEFAULT_PATCH = Path(__file__).resolve().parents[2] / "patches" / (
    "0001-isolate-usb-profile-stack-and-fix-rom-metadata.patch"
)


def command(*args, cwd):
    return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()


def rehearse(checkout: Path, patch: Path) -> dict:
    checkout = checkout.resolve()
    patch = patch.resolve()
    head = command("git", "rev-parse", "HEAD", cwd=checkout)
    if head != RON7_SHA:
        raise ValueError("refuse to inspect non-pinned Ron7 checkout")
    original = {}
    for filename in FILES:
        original[filename] = (checkout / filename).read_bytes()
        base = subprocess.check_output(["git", "show", f"{RON7_SHA}:{filename}"], cwd=checkout)
        if original[filename] != base:
            raise ValueError(f"source modified relative to pinned commit: {filename}")

    with tempfile.TemporaryDirectory(prefix="eleafer-ron7-patch-") as tmp:
        root = Path(tmp)
        for filename in FILES:
            dest = root / filename
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(original[filename])
        command("git", "apply", "--check", str(patch), cwd=root)
        command("git", "apply", str(patch), cwd=root)
        usb = (root / "src/meusbd.c").read_text()
        asm = (root / "src/myevic.s").read_text()
        ld = (root / "linker.ld").read_text()

        start = usb.index("void hidGetOutReport(")
        usb_handler = usb[start:]
        checks = {
            "noinline_profile_page_helper": (
                '__myevic__ __attribute__((noinline)) static void hidWriteStoredProfile( dfParams_t *p )'
                in usb
            ),
            "profile_persistent_write_preserved": (
                "FMCEraseWritePage( DATAFLASH_PROFILES_BASE, (uint32_t*)page );" in usb
                and "hidWriteStoredProfile( p );" in usb_handler
                and "SaveProfile();" in usb_handler
            ),
            "no_2kb_stack_page_in_usb_entry": (
                "uint8_t page[FMC_FLASH_PAGE_SIZE]" not in usb_handler
            ),
            "no_new_scratch_bss": (
                "static uint8_t page[FMC_FLASH_PAGE_SIZE]" not in usb
            ),
            "noload_sram": ".sram (NOLOAD) : {" in ld,
            "msc_fw_size_includes_raminit": (
                "GetFirmwareSize:\n\t\tldr\t\tr0, =RAMInitEnd\n\t\tbx\t\tlr" in asm
            ),
        }
        if not all(checks.values()):
            raise AssertionError(f"source patch invariant failure: {checks}")
        return checks


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checkout", type=Path, required=True, help="read-only original Ron7 checkout")
    ap.add_argument("--patch", type=Path, default=DEFAULT_PATCH)
    a = ap.parse_args()
    for name, ok in rehearse(a.checkout, a.patch).items():
        print(f"{'PASS' if ok else 'FAIL'}  {name}")
    print("PASS  temporary git apply; fixed-source original left untouched")
    print("NOT_RUN: full ARM build, hardware, USB, FLASH, runtime stack measurement")


if __name__ == "__main__":
    main()
