# Ron7 E115オフライン再検証

このフォルダには、以前の監査で作成・検証した**固定Ron7ソース向け**の試験コードがある。Eleafer Madnessへ移しただけで、移管後のビルド・55件再実行は**未実施**。実機接続コード、FW書込コード、配布用ファームウェアは含まない。

- `ron7_artifact_audit.py`：ELFセクション、PT_LOAD、選択BINバイト、初期化テーブルの整合性を解析する。
- `test_ron7_artifact_audit.py`：合成ELFによる不具合・構造テスト。
- `test_ron7_native.py`と`ron7_fixture/`：固定Ron7ソースから小さなC断片を抽出し、host nativeの不具合反例を調べる。FIRE・HID通信は実行しない。
- `e115_stock_zip_audit.py`：所有する正規ZIP候補のZIP/PE/APROM整合の**オフライン静的検査のみ**。ZIPをgit管理に追加しない。
- `ron7_build.Dockerfile`、`ron7_rebuild.sh`：過去の隔離再現環境の記録。`ron7_rebuild.sh`は`/audit/sdk`や`/audit/build-default`など、別途準備する固定配置を前提にしており、単体での実行を保証しない。

## 簡易テスト（Python 3）

このディレクトリをカレントにして：

```shell
python3 -m unittest -v test_ron7_artifact_audit.py test_e115_stock_zip_audit.py
```

native試験を含む実行：

```shell
ELEAFER_RON7_SOURCE=/path/to/checkout-of-08202453b54c2284df27c9f188f66c2b2fb0f92e python3 -m unittest discover -v
```

`ELEAFER_RON7_SOURCE`は元のRon7コミットをcheckoutしたディレクトリ。native試験はコミットSHAと入力ファイル内容を検査してからホストCをビルドする。未指定時はnative試験をskipするため、**「移行後に55件すべてPASS」とは主張しない。** 実機の安全性証明ではない。

履歴の機械可読な結果は [`evidence/ron7_artifact_audit_20261026.json`](../../evidence/ron7_artifact_audit_20261026.json)を参照。過去の`55件成功`は問題を再現する試験も含む。

**絶対に実機へFWを送信しない。** 主目的はRon7版の現行機能の実機確認に必要な安全条件の整理であり、別プロジェクトの新機能実装ではない。
