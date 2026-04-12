## コミット前チェック

`bin/ci` を実行して全ステップがパスすること。

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI（rubocop, bundler-audit, importmap audit, brakeman, テスト, seed）
bin/rails test   # テストのみ
bin/rubocop      # Lintのみ
```
