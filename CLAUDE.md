# Tsubame - Feed Reader

Fastladder互換のフィードリーダー。シングルユーザー向け。

## 技術スタック

- Ruby 4.0 / Rails 8.1 / SQLite3
- Hotwire (Turbo + Stimulus) + Vanilla CSS
- Solid Queue (バックグラウンドジョブ)
- Kamal (デプロイ先: さくらのVPS)

## アーキテクチャ方針

- **37signals コーディングスタイル準拠**
  - リッチドメインモデル（サービスオブジェクト不使用）
  - CRUDベースのコントローラー
  - バニラRails（外部gem最小限）
  - Vanilla CSS（プリプロセッサなし）
- **シングルユーザー**: User モデルは認証用のみ。Subscription中間テーブルなし
- **フィードパース**: Ruby標準ライブラリ `rss` を使用（外部gem不使用）

## ワークフロー

### コミット前チェック

`bin/ci` を実行して全ステップがパスすること。

### エージェントワークフロー

各機能の実装は以下の順序で進める:

1. **rails-architect** — 設計・計画を作成
2. **plan-reviewer** — 計画をレビュー（Must Fix があれば rails-architect に差し戻し）
3. **db-engineer** — マイグレーション実装
4. **logic-implementer** — コントローラー・モデル実装
5. **stimulus-implementer** — Stimulus コントローラー・ビュー実装
6. **ui-specialist** — UI/UX・アクセシビリティレビュー
7. **qa-engineer** — テスト・品質確認
8. **code-reviewer** — 最終レビュー

デプロイ関連は **kamal-expert** が担当。

## ドキュメント

詳細設計は `docs/` ディレクトリを参照:

- [docs/architecture.md](docs/architecture.md) — アーキテクチャ概要
- [docs/data_model.md](docs/data_model.md) — データモデル定義
- [docs/keyboard_shortcuts.md](docs/keyboard_shortcuts.md) — キーボードショートカット一覧
- [docs/feed_crawling.md](docs/feed_crawling.md) — フィードクロール設計
- [docs/deployment.md](docs/deployment.md) — デプロイ手順

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI（rubocop, security audit, テスト）
bin/rails test   # テストのみ
bin/rubocop      # Lintのみ
```
