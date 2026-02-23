# Tsubame

Fastladder 互換のパーソナルフィードリーダー。シングルユーザー向けのセルフホスト型アプリケーション。

## 主な機能

- 3 ペイン UI（フィード一覧 / エントリ一覧 / エントリ本文）
- Fastladder 互換キーボードショートカット（j/k/s/a/v/p/o/r/Shift+A）
- OPML インポート・エクスポート
- 定期フィードクロール（RSS 2.0 / Atom / RDF 対応）
- エントリの既読管理・ピン留め
- モバイル対応・ダークモード対応

## 動作要件

- Ruby 4.0+
- SQLite3

## セットアップ

```bash
git clone https://github.com/ryu/tsubame.git
cd tsubame
bin/setup
```

初回ユーザーを作成:

```bash
TSUBAME_EMAIL=you@example.com TSUBAME_PASSWORD=your_password bin/rails db:seed
```

開発サーバーを起動:

```bash
bin/dev
```

http://localhost:3000 にアクセスしてログイン。

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI (rubocop, security audit, テスト)
bin/rails test   # テストのみ
bin/rubocop      # Lint のみ
```

## デプロイ

Kamal 2 を使った Docker デプロイに対応。詳細は [docs/deployment.md](docs/deployment.md) を参照。

```bash
kamal deploy
```

## 技術スタック

- Ruby 4.0 / Rails 8.1 / SQLite3
- Hotwire (Turbo + Stimulus) + Vanilla CSS
- Solid Queue (バックグラウンドジョブ)
- Kamal 2 (デプロイ)

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — アーキテクチャ概要
- [docs/data_model.md](docs/data_model.md) — データモデル定義
- [docs/keyboard_shortcuts.md](docs/keyboard_shortcuts.md) — キーボードショートカット一覧
- [docs/feed_crawling.md](docs/feed_crawling.md) — フィードクロール設計
- [docs/deployment.md](docs/deployment.md) — デプロイ手順

## ライセンス

[MIT License](LICENSE)
