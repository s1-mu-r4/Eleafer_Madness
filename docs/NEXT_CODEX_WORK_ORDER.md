# Ron7 E115｜Codex向け最小修正・実機確認準備

**目的はRon7公開`pufflimit`の既存機能をE115/HW1.00で検証することだけ。** 既存機能以外の仕様・データ領域を追加実装・採点しない。

## 入力

- 本リポジトリ[検証正本](RON7_E115_VERIFICATION.md)、[移管したオフラインテスト](../tests/offline/README.md)、[履歴JSON](../evidence/ron7_artifact_audit_20261026.json)。
- Ron7固定SHA：`wighawag/myevic@08202453b54c2284df27c9f188f66c2b2fb0f92e`。
- ユーザー所有個体はE115/HW1.00/FW5.04。USB GETINFOとLDROM起動応答は読取専用で確認済みだが、純正書戻し成功とCONFIGは未確認。

## 一括作業

1. **既知の実害要因に限定して修正**：`hidGetOutReport`から`SaveProfile`への静的ネスト・スタック下限4,152Bが予約4,096Bを超える問題を、保護動作・機能仕様を変えずに解消。単にコンパイルのスタック領域を拡大するだけで、他のRAMや割込み余裕を未検証のままPASSにしない。
2. **実際に使用する更新BINを正しく検証**：ELF LMAの16B重複（10B不一致）と最終選択セクションBINの関係を独立判定。`.raminit`全24B、`.data`初期化、`.sram`の配置、MSC経由書出しサイズの欠落を点検。どの経路が修正必須か根拠を示す。
3. **不正な読取命令を安全に処置**：FMCREADの長さ検査式と範囲境界をレビューし、最小修正または未使用経路の確実な無効化を選定。アトマイザ通電・HID実送信は禁止。
4. **Ron7の仕様を維持した回帰**：パフ数カウンタ、`FireDuration > 5`のクリック閾値、時間窓、RTC消失・fail-closed設定、DataFlash保存遅延、既存の電池/温度/短絡/過電流/10秒保護を検査。現在の動作と観察・制約を記録し、勝手に秒数制限へ置き換えない。重大な安全問題は例外として特定し停止する。
5. **再現とGo/No-Go**：クリーンビルド2回、ELF/平文BIN/変換BINバイト一致、ROM/RAMとスタック保守上限、テストをログ化。純正LDROMの消去・復旧成功は未確認のまま実機書込へ進まない。分解・Nu-Link・SWDや自動FW書込へ移行しない。

## 成果物と禁止事項

この**Eleafer Madness**のDraft PR #1に、最小修正の検討・パッチ候補（必要なら独立の研究用ブランチ）・テスト・明確な書込Go/No-Go判定を集約。ユーザー承認前に本番用FWを配布したり、実機へ書き込んだり、mainへマージしたりしない。

**対象はRon7版の最小修正だけ。** 他のリポジトリや未採択の新機能へ作業を広げない。純正復旧経路が確証できない場合は、No-Goのまま阻害理由を1件に集約して報告する。

## 2026-10-26：最小修正パッチを用意（初期の検証時点）

[候補パッチ](../patches/0001-isolate-usb-profile-stack-and-fix-rom-metadata.patch) と[説明](../patches/README.md)を追加した。固定SHAのRon7 3ファイルから差分を生成して、全4ハンクが元ソースに**逐語一致して適用可能**なことをGitHub上の読取データで確認。ただし実際のARM GCCフルビルド・実機操作は未実施。

- `meusbd.c`：USB profile書込の2KiBローカル配列をnoinline helperへ分離。重なるSaveProfile呼出しの同時スタック使用を回避する候補であり、レジスタ退避・割込み・他calleeを含む安全なスタック余裕の証明は**まだない**。
- `linker.ld`：`.sram (NOLOAD)`候補。ホストClang/lldの最小ARM例では`.sram`がNOBITSになることは確認したが、Ron7の実ELFでROM LMA競合が消えたとは**未確認**。
- `myevic.s`：MSC出力長を`RAMInitEnd`までにする候補。固定リンク定義のROM起点0を前提とし、書込用BINハッシュ・読み出しサイズをフルビルド後に実測する。

**次のCodex開始手順：**

1. このEleafer PRブランチを取得し、Ron7固定SHAを別の隔離作業領域にcheckoutする。
2. `python3 tests/offline/validate_ron7_minimal_patch.py --checkout <固定SHAのRon7 checkout>` を実行（内部で一時複製へ`git apply --check`／apply、元checkoutへの書込みなし）。
3. 作業用コピーにパッチを適用し、同一固定ツールでクリーンビルド2回／ELF・BIN照合／スタックフレーム全呼出し経路／USB MSCサイズを確認する。**合格を勝手に判定しない**。
4. FMCREADの安全問題は別論点として、当該Ron7の既存使用契約を静的確認してから最小修正する。FIRE制限やDataFlash仕様は変更しない。
5. 結果のみ本Draft PR #1へ反映、mainマージも実機書込みもなし。いずれかの検証が不成立ならNO-GOを維持する。


## 最新の切り分け

パッチ0001は[実際のARMオフラインビルドでPASS](https://github.com/s1-mu-r4/Eleafer_Madness/actions/runs/40234610086)。FMCREAD最小のパッチ0002を追加し、同じ再現環境で再実行する。**Ron7既存の機能・保存形式を無断変更しない。** 次のGateは純正LDROM復旧動作で、読取専用のGETINFO成功から復旧書込み成功を推定しない。
