# Tsubame

Fastladder 互換のパーソナルフィードリーダー。シングルユーザー向け。

## 技術スタック

- Ruby 4.0 / Rails 8.1 / SQLite3
- Hotwire (Turbo + Stimulus) + Vanilla CSS
- Solid Queue (バックグラウンドジョブ)
- Kamal 2 (デプロイ)

## 主な機能

- OPML インポートによるフィード一括登録
- 定期フィードクロール (Solid Queue)
- 3 ペイン UI (フィード一覧 / エントリ一覧 / エントリ本文)
- Fastladder 互換キーボードショートカット (j/k/s/a/v/p/o/r/Shift+A)
- エントリの既読管理・ピン留め

## セットアップ

```bash
bin/setup
bin/dev
```

初回起動後 http://localhost:3000 にアクセスし、`db/seeds.rb` に定義されたユーザーでログイン。

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI (rubocop, security audit, テスト)
bin/rails test   # テストのみ
bin/rubocop      # Lint のみ
```

## デプロイ

Kamal 2 でさくらの VPS にデプロイ。詳細は [docs/deployment.md](docs/deployment.md) を参照。

```bash
kamal deploy
```

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — アーキテクチャ概要
- [docs/data_model.md](docs/data_model.md) — データモデル定義
- [docs/keyboard_shortcuts.md](docs/keyboard_shortcuts.md) — キーボードショートカット一覧
- [docs/feed_crawling.md](docs/feed_crawling.md) — フィードクロール設計
- [docs/deployment.md](docs/deployment.md) — デプロイ手順
