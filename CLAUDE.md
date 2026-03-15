# Tsubame - Feed Reader

Fastladder互換のフィードリーダー。複数ユーザー対応。

## 技術スタック

- Ruby 4.0 / Rails 8.1 / SQLite3
- Hotwire (Turbo + Stimulus) + Vanilla CSS
- Solid Queue (バックグラウンドジョブ)
- Kamal (デプロイ先: さくらのVPS)

## モジュール構成

### モデル

- `Feed` — フィード管理（グローバル共有）。concern: `Fetching`, `Autodiscovery`, `EntryImporter`, `Opml`
- `Entry` — エントリー管理（グローバル共有）。concern: `RssParser`
- `Subscription` — ユーザーとフィードの中間テーブル（フォルダ・レート・カスタムタイトル管理）
- `UserEntryState` — ユーザーごとの既読/ピン状態（行なし＝未読・未ピン）
- `Folder` — フォルダによるフィード分類（ユーザーごと）
- `User` — 認証・購読管理・既読/ピン状態管理

### コントローラー

- `HomeController` — メイン画面（フィード一覧 + エントリー一覧）
- `FeedsController` / `EntriesController` — CRUD
- `EntryPinsController` — ピン留め
- `EntryMarkAsReadsController` / `FeedMarkAsReadsController` — 既読管理
- `FeedImportsController` / `FeedExportsController` — OPML インポート/エクスポート
- `FeedFetchesController` — 手動フェッチ
- `PinnedEntryOpensController` — ピン留めエントリー一括開封

### Stimulus コントローラー

- `keyboard_controller` — キーボードショートカットのルーター
- `selection_controller` — フィード/エントリーのナビゲーション・選択状態
- `pin_controller` — ピン留めトグル・一括開封
- `help_dialog_controller` — ヘルプダイアログ
- `hatena_bookmark_controller` — はてなブックマーク数表示
- `mobile_pane_controller` — モバイルペイン切り替え
- 共通ヘルパー: `lib/fetch_helper.js`

### ジョブ

- `FetchFeedsJob` — 全フィード定期クロール
- `FetchFeedJob` — 個別フィードフェッチ
- `CleanupEntriesJob` — 古いエントリーの削除

## セッション開始手順

1. `docs/` ディレクトリの関連ドキュメントを確認する
2. `git status` で現在の状態を把握する
3. 変更対象のコードを読んでから作業を開始する

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — アーキテクチャ概要
- [docs/data_model.md](docs/data_model.md) — データモデル定義
- [docs/keyboard_shortcuts.md](docs/keyboard_shortcuts.md) — キーボードショートカット一覧
- [docs/feed_crawling.md](docs/feed_crawling.md) — フィードクロール設計
- [docs/deployment.md](docs/deployment.md) — デプロイ手順
- [docs/backup.md](docs/backup.md) — バックアップ手順
