# Tsubame - Feed Reader

Fastladder 互換のフィードリーダー。Ruby 4.0 / Rails 8.1 / SQLite3 / Hotwire / Kamal（さくらのVPS）。

## このリポジトリ固有の前提

コードを読んでも分からない判断だけをここに書く。構成はコードと `docs/` を参照すること。

- **シングルユーザー運用**: データモデルは複数ユーザーを許容するが、設計判断はシングルユーザーを優先する。既知のトレードオフは [docs/architecture.md](docs/architecture.md) 参照
- **状態はレコードで表現**: 既読・ピンは boolean カラムでなく `UserEntryState` の行の有無で持つ（行なし＝未読・未ピン）
- **Feed / Entry はグローバル共有**: ユーザー固有の情報は `Subscription` / `UserEntryState` 側に置く
- **フィードパース**: Ruby 標準ライブラリ `rss` を使う。パーサ用の gem は追加しない
- **DB バックエンド**: Solid Queue / Solid Cache / Solid Cable。Redis は使わない
- **モデルの concern**: 50〜150行が目安。200行を超えたら責務分割を検討する

コーディングスタイルは `.claude/rules/dhh_style.md`。

## 開発コマンド

```bash
bin/setup        # 初期セットアップ（bundle, db:prepare, ログクリア）
bin/dev          # 開発サーバー起動
bin/ci           # CI全実行（rubocop, bundler-audit, importmap audit, brakeman, テスト, seed）
bin/rails test test/models/feed_test.rb  # 単一ファイル実行
```

コミット前は必ず `bin/ci` を全パスさせること。

## ドキュメント

必要になった時点で読む。

- [docs/architecture.md](docs/architecture.md) — システム構成・フロントエンド構成・設計上のトレードオフ
- [docs/data_model.md](docs/data_model.md) — テーブル定義とリレーション
- [docs/feed_crawling.md](docs/feed_crawling.md) — クロールのジョブ構成・スケジューリング
- [docs/entry_dedup_design.md](docs/entry_dedup_design.md) — エントリ重複排除の設計
- [docs/magic_link_auth.md](docs/magic_link_auth.md) — マジックリンク認証の設計
- [docs/keyboard_shortcuts.md](docs/keyboard_shortcuts.md) — キーボードショートカット一覧
- [docs/deployment.md](docs/deployment.md) — デプロイ手順
- [docs/backup.md](docs/backup.md) — バックアップ手順
