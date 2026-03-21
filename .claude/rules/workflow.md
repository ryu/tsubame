## コミット前チェック

`bin/ci` を実行して全ステップがパスすること。

## エージェントワークフロー

ユーザーが新機能の追加・既存機能の変更・設計判断を伴う作業を依頼した場合、**明示的な指示がなくても以下のワークフローを自動的に順番に実行する**こと。バグ修正や軽微な変更（typo修正、文言変更など）は対象外。

各機能の実装は以下の順序で進める:

1. **rails-architect** — 設計・計画を作成
2. **plan-reviewer** — 計画をレビュー
3. **⏸ ユーザー確認** — レビュー結果を提示し、実装に進むか再設計するかユーザーに確認する。承認されるまで次に進まない
4. **db-engineer** — マイグレーション実装（DB変更がない場合はスキップ）
4. **logic-implementer** — コントローラー・モデル実装
5. **stimulus-implementer** — Stimulus コントローラー・ビュー実装（フロントエンド変更がない場合はスキップ）
6. **qa-engineer** — テスト・品質確認
7. **code-reviewer** — 最終レビュー

デプロイ関連は **kamal-expert** が担当。

## 開発コマンド

```bash
bin/dev          # 開発サーバー起動
bin/ci           # CI（rubocop, bundler-audit, importmap audit, brakeman, テスト, seed）
bin/rails test   # テストのみ
bin/rubocop      # Lintのみ
```
