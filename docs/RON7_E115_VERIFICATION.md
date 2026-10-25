# Ron7 `pufflimit`｜E115実機検証の現状と出口条件

最終整理：2026-10-26。**このプロジェクトの目的は、公開されているRon7版を最小限の安全修正のうえeVic VTwo Mini（E115）実機で動作確認すること。** 新しい機能群の実装、別プロジェクトの製品仕様を満たすことではない。

## 対象・固定ソース

- 対象機：Joyetech eVic VTwo Mini、E115、HW 1.00、純正FW 5.04。
- Ron7 `pufflimit`：[`wighawag/myevic@08202453b54c2284df27c9f188f66c2b2fb0f92e`](https://github.com/wighawag/myevic/tree/08202453b54c2284df27c9f188f66c2b2fb0f92e)。
- 上流：[`ClockSelect/myevic@546394bcf1ac9ab63381fa2fb484a0dfa11d443f`](https://github.com/ClockSelect/myevic/tree/546394bcf1ac9ab63381fa2fb484a0dfa11d443f)。
- 元のRon7ブランチは**変更していない**。過去の分析はDOPEY側の[PR #24](https://github.com/s1-mu-r4/dopey/pull/24)・[PR #25](https://github.com/s1-mu-r4/dopey/pull/25)で行われた。本書はそこからRon7実機検証に関係する事実のみを独立記録したもので、DOPEYの要求やB1ゲートは採用しない。

## 実機の読み取り専用証拠（ユーザー報告／USER_LOG_PASS）

| 観測 | 結果 | 限界 |
|---|---|---|
| GETINFO `0x35` | E115 / HW 1.00 / FW 5.04 | 論理2044B応答、物理Flash全域ではない |
| GETINFO二重保存 | `E115-before-1.bin` と `E115-before-2.bin`、各2044B、SHA256同一 `a9176d6d5f570f9152f3ec43b067b76ae88bae299aa81a988a0cdce32b914d40` | 機密情報を含み得る元BINは非公開 |
| 別ドライブコピー | `H:\E115-backup`で同じハッシュを再確認 | 独立物理媒体か不明 |
| FMC情報 | CID `0xDA`、DID `0x2980`、PID `0x00845201` | 固定[myevic情報部構造](https://github.com/ClockSelect/myevic/blob/546394bcf1ac9ab63381fa2fb484a0dfa11d443f/inc/dataflash.h)のオフセットを仮定 |
| MCU候補 | PIDはOpenOCDのM452LE6AE定義と一致（128KiB Flash／32KiB RAM） | MCUの現物刻印・CONFIG0/1を直接確認していない |
| 復旧側起動 | バッテリー・アトマイザーなし、＋ボタン保持USB接続、FW version 0 / LDROM version 100、VID:PID `0416:5020` | LDROMのGETINFO応答は確認済み。**Flash復旧書込の成功は未検証** |

ユーザーは上記を読取専用ツールで取得した。実機へのFW書込・CONFIG変更・FIRE操作は行っていない。

## 純正復旧候補（オフライン）

- Joyetech公式E115向けFW5.04 Windows ZIP：SHA256 `20ed1e118745c25df8b3c4dda036a2cc0f1c45a0a3bae6955a41178517fb9ed9`。
- 内部 `eVic_VTwo_mini_V5.04.bin` 70,904B。APROM復号後のE115製品識別値に整合する。
- 純正のWindows/Macアップデータが通常要求するのは開始アドレス0、BIN実サイズと静的解析で確認されたが、**個体LDROMの内部消去範囲・中断復旧は未取得**。
- 通常起動のGETINFOダンプは物理APROM/LDROM/CONFIGの全バックアップではない。純正ファイルを所持することは完全な復旧保証ではない。

原資料：[公式更新パッケージの旧監査](https://github.com/s1-mu-r4/dopey/blob/370517a29db0589b11b7bfbbae9faca50b90ac1b/docs/reports/b1/B1_E115_STOCK_UPDATE_AUDIT.md)。機能仕様へは転用しない。

## Ron7固定SHA 再現ビルド（オフライン／OFFLINE_INSPECTED）

過去Codex作業コミット：[`370517a`](https://github.com/s1-mu-r4/dopey/commit/370517a29db0589b11b7bfbbae9faca50b90ac1b)。固定Dockerイメージ・BSP・日時でクリーンビルド2回。ELF／平文BIN／変換BINがそれぞれバイト一致。**実機では動かしていない。**

| 成果物・条件 | 結果 |
|---|---|
| 平文／変換BIN | 各100,456B |
| 平文BIN SHA256 | `833e30e43a4a261d40e2e99b8de64c7f745818421f8dd292f49987b7f71fe2a6` |
| 変換BIN SHA256 | `a8d8a7807784765e64fd00d2498a7ae9574f0dc5e613a9db5616de7207bab0b8` |
| ELF SHA256 | `23a331818a493a2d95a1f8cd6a8933d5541eda80a8deff78af1d67bd3ca71b5f` |
| 100KiB ROM予算 | 残1,944B |
| ゲーム有効ビルド | 2,572B超過でリンク失敗 |
| オフライン試験 | 55件成功・失敗0・skip0（不具合再現の成功を含む） |

**既知の投入前問題**

1. プロファイル保存経路で`hidGetOutReport`→`SaveProfile`の静的スタック下限4,152Bに対し予約4,096B（最低56B超過）。**現行ビルドの安全上の不合格**。
2. ELFの`.sram`と`.raminit`のLOAD LMAが16B重複、うち10Bの実バイトが異なる。選択セクションから再構成した**最終BINは一致**しており、ELF全LOADをそのまま書く経路とBINを分けて評価すること。
3. USB MSC経由のFW仮想ファイルはRAM初期化表24Bをサイズ算入しない。アップデート用BINとは別の問題。
4. FMCREAD `0xC0` 受信長検査に演算子の優先順位の誤りがある。stock FW・LDROM上の動作は未知、**実機でこのコマンドを送らない**。
5. Ron7版の独自制限には`FireDuration > 5`（0.5秒超のみパフ加算）、時計不信時の残枠許可、遅延保存等の挙動がある。**Ron7版本来の機能・既知制約として記録し、外部の別製品要件を満たさないことを理由に不合格としない。** 安全上の実害や検証阻害につながる部分は個別に評価する。

[機械可読なビルド監査結果](../evidence/ron7_artifact_audit_20261026.json)。実機へ投入するBIN/ELFはGitHubにコミットしない。

## Ron7版の検証だけに必要な次作業

1. **最小修正案**：スタック超過を解消する。ELF重複・MSC・FMCREADは影響経路を確認し、実機検証の前に必要な修正・隔離だけを選ぶ。機能拡張・仕様変更をしない。
2. **再ビルド・回帰**：固定SHAの元の挙動、既存保護、E115製品コード、初期化、Ron7パフ数制限／時計挙動を検証。ダミー実行を安全実機合格としない。
3. **復旧経路の確認**：当該E115のLDROMからの純正FW復旧書込は未確認。分解／Nu-Link／SWDを使わない。安全な復旧見通しを確立できない場合はNO-GOのまま。
4. **将来の別途承認のある実機テスト**：まずアトマイザ・セルなし起動／表示／USB認識。電気的FIRE保護・パフ数／時間窓／RTC喪失の確認は無害なベンチ条件が確立してから分離して行う。実行は未許可。

**現在はFW実機書込NO-GO。元のRon7版で実機起動した実績はない。** 研究結果を試験合格や実機安全性の証明に昇格しない。


## 2026-10-26 ARM GCC検証（Eleafer Actions #2）

[Actions #2](https://github.com/s1-mu-r4/Eleafer_Madness/actions/runs/40234610086) にて**パッチ0001のみ**の固定ソース／GCC12.2.1隔離クリーンビルド2回が成功。ELF・平文BIN・変換BINがそれぞれ完全一致。パッチの一時複製適用チェック6件、合成ELF7件、公式ZIP形式モック6件、固定Ron7 C native14件が成功。実機未接続。

| 項目 | パッチ0001結果 |
|---|---|
| ELF SHA256 | `98d6b105d66ef0b61afa54e11038ac78f0f7fcd01c63f2762580845f26111070` |
| 平文BIN SHA256 | `12b64021b644afcfd9837a763cbb26d5ea1fa819c1078118445360951e14e2b3` |
| 変換BIN SHA256 | `c102d6ab5c8bf77e7919e9ee35c1eb4103b4781cb8ea57c7ad58996d74dc56b7` |
| ROMサイズ | 100,476B、残1,924B |
| `hidGetOutReport` フレーム | 72B（元2,080B） |
| `SaveProfile`／noinline helper | 2,072B／2,064B |
| 直接ネストフレーム | 2,144B／2,136B、4KiB未満（割込み等の総計ではない） |
| ELF `.sram` | NOBITS、PT_LOADバイト衝突なし |
| MSC取得サイズ | RAMInitEndとBIN排他終端が一致 |

**No-Go継続**：割込み最大スタック・保護機能の実機回帰・純正LDROM復旧可能性は未確認。パッチ0002 FMCREAD長さ・アドレスの境界検査は次の独立修正候補であり、Actions #2には含まれない。
