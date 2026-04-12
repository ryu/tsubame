## DHH / 37signals コーディング規約（詳細）

### 命名規則

- **動詞メソッド**: 状態を変える操作は明確な動詞（`card.close`, `card.reopen`, `board.publish`）。`set_xxx` や `update_xxx_status` は使わない
- **述語メソッド**: 状態の問い合わせは `?` 付き（`card.closed?`, `board.published?`）。関連レコードの有無で判定
- **Concern 名**: 能力を表す形容詞（`Closeable`, `Publishable`, `Watchable`）。`XxxHelpers` は不可
- **スコープ名**: 業務用語（`chronologically`, `reverse_chronologically`, `alphabetically`, `latest`, `preloaded`, `active`）。SQL的な名前（`ordered_by_created_at`）は避ける

### REST マッピング

カスタムアクションは作らない。動詞を名詞リソースに変換する:

- `POST /cards/:id/close` → `POST /cards/:id/closure`（create）
- `DELETE /cards/:id/close` → `DELETE /cards/:id/closure`（destroy）
- 1対1の状態は `resource`（単数形）、1対多は `resources`（複数形）

### 状態はレコードで表現

boolean カラムでなく、別テーブルのレコード有無で状態を管理する:

- `Card.joins(:closure)` = クローズ済み
- `Card.where.missing(:closure)` = オープン
- 利点: 誰が・いつ変更したかを自動記録、`joins` / `where.missing` で直感的にクエリ可能

### モデル

- **認可ロジックはモデルに置く**: `User#can_administer?(resource)` パターン。pundit / cancancan 不使用
- **コールバックは控えめに**: `after_commit` で非同期処理、`before_save` で導出データのみ。複雑なチェーンや業務ロジックをコールバックに入れない
- **bang メソッド優先**: `create!`, `update!`, `destroy!` で失敗時に例外を発生させる。静かに失敗させない
- **Current attributes**: `belongs_to :creator, default: -> { Current.user }` で作成者を自動設定
- **normalizes**: `normalizes :email, with: ->(e) { e.strip.downcase }` でデータ正規化
- **DB 制約 > モデルバリデーション**: データ整合性はユニークインデックス・外部キーで担保

### コントローラー

- **Concern で共有行動を抽出**: `XxxScoped`（リソース読み込み）、認可チェック等
- **認可は before_action**: モデルの認可メソッドを呼ぶ形

### ジョブ

- **薄いラッパー**: ジョブはモデルメソッドを呼ぶだけ。ロジックはモデル側
- **命名**: `_later`（非同期）/ `_now`（同期）サフィックスでモデルから呼び出し
- **エラー処理**: `retry_on`（一時エラー）/ `discard_on`（永続エラー）を使い分け

### フロントエンド

- **Stimulus**: 単一責務、50行以内が目安。Values API でデータ渡し、disconnect でクリーンアップ
- **Turbo Stream**: 部分更新に使用。morph で複雑な更新
- **CSS**: ネイティブ CSS（`@layer`, ネスティング, CSS 変数）。プリプロセッサ・Tailwind 不使用
- **パーシャル**: ViewComponent 不使用。標準パーシャルで十分

### テスト

- **Minitest + fixtures**: RSpec / factory_bot は使わない
- **fixtures はシンプルに**: 最小限のデータで十分

### 避けるべき gem

devise, pundit, cancancan, sidekiq, redis, view_component, GraphQL, factory_bot, rspec, Tailwind。
Rails 標準機能や自前実装（150行以内で書けるなら）を優先する。

### Ruby 構文

- シンボル配列: `%i[ show edit update destroy ]`（角括弧内にスペース）
- private 以下のメソッドは2スペースインデント
- 単純な条件分岐はテルナリー演算子
- 複数条件は expression-less `case`（`case` の後に変数を置かない）
