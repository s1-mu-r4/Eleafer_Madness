# Ron7 E115 minimal preflash patch candidate (NOT BUILT)

Original fixed source: `wighawag/myevic@08202453b54c2284df27c9f188f66c2b2fb0f92e`.

Patch `0001-isolate-usb-profile-stack-and-fix-rom-metadata.patch` proposes ONLY three surgical adjustments:
1. Move the 2 KiB USB SETPROFILE scratch page into a **noinline** `.myevic` helper, so it cannot coexist on the call stack with SaveProfile's own 2 KiB scratch frame. The scratch buffer remains stack-local, not shared across interrupt contexts. No profile format, write order or limits are changed.
2. Change linker section `.sram` to `(NOLOAD)` to express that BSS and reserved stack are zero-initialized by the existing RAMInitTable rather than copied as Flash image. **Full ARM linker/BIN validation REQUIRED**; Clang/lld cross-compile microfixture only corroborates PROGBITS→NOBITS.
3. Make `GetFirmwareSize()` report `RAMInitEnd` (exclusive end) so the MSC virtual FW read includes the trailing 24-byte RAMInitTable. Assumes ROM origin 0 per the pinned linker. Compare to actual converter and objcopy output.

**Do not flash, distribute a patched firmware, or merge into main.** This patch has not been applied to a full Ron7 checkout or ARM GCC-clean-built. Require a fixed-toolchain reproducible build, ELF PADDR overlaps cleared, stack usage proof including interrupts, binary exact selected-section reconstruction, MSC FW length check, regression tests, and stock recovery analysis before changing the No-Go.

Unchanged: Ron7 `pufflimit` policy, dataflash layout, existing thermal/battery/short protection, HID command set, device IO.

Known unaddressed risk: `HID_CMD_FMCREAD` bad precedence and missing address scope. A separate patch must either validate safe command bounds or make this mode unreachable; never use it on the real device before review.

Run on isolated *pinned clean checkout*: `git apply --check <patch>`, then `git apply <patch>`, fixed SHA build, readelf, objdump, source tests. **Patch does not touch DOPEY.**


## パッチ0002：FMCREADの受信長・アドレス算術チェック

[0002-harden-fmcread-validation.patch](0002-harden-fmcread-validation.patch) は、Ron7既存の`hidFMCReadCmd`における`! len % EP2_MAX_PKT_SIZE`の優先順位不備を修正し、ゼロ長、64B非整列長、4B非整列アドレス、32-bitアドレス加算オーバーフローを拒否する。2KiB超の要求はもとのストリーミング読み込み仕様として保持する。原本Ron7固定SHAを変更せず、**0001の後で**適用する。受信コマンドの物理アドレスホワイトリストや、stock LDROMでの安全性を証明しない。

[validate_fmcread_guard.py](../tests/offline/validate_fmcread_guard.py) はpatched Cから条件式を抽出し、スタンドアロンのCネイティブ11ベクトルで判定を検査する。実機には送信しない。パッチ0002適用後の全ARM再ビルドの結果を取得するまでは**修正済み合格と認定しない**。
