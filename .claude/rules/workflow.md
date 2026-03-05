## コミット前チェック

`bin/ci` を実行して全ステップがパスすること。

## エージェントワークフロー

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

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI（rubocop, bundler-audit, importmap audit, brakeman, テスト, seed）
bin/rails test   # テストのみ
bin/rubocop      # Lintのみ
```
