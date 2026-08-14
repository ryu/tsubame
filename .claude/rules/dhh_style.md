# コーディングスタイル（DHH / 37signals 準拠）

このプロジェクトで意図的に選んでいる方針。一般的な Rails の作法は書かない。

## 構造

- **リッチドメインモデル**: サービスオブジェクト・フォームオブジェクトは作らない。ロジックはモデルと concern に置く
- **CRUD ベースのコントローラー**: 標準7アクションのみ。カスタムアクションが欲しくなったら新しいリソースを作る
  - `POST /cards/:id/close` ではなく `POST /cards/:id/closure`（create）
  - 1対1の状態は単数形 `resource`、1対多は複数形 `resources`
- **状態はレコードで表現**: boolean カラムでなく関連レコードの有無で持つ。`joins(:closure)` / `where.missing(:closure)` で引ける
- **認可はモデルに置く**: `User#can_administer?(resource)` パターンを before_action から呼ぶ。pundit / cancancan は使わない
- **ジョブは薄いラッパー**: モデルメソッドを呼ぶだけ。モデル側は `_later` / `_now` サフィックスで公開する

## 命名

- 状態を変える操作は動詞（`feed.subscribe`）。`set_xxx` / `update_xxx_status` は使わない
- 状態の問い合わせは述語（`entry.read?`）
- concern 名は能力を表す形容詞（`Fetchable`, `Subscribable`）。`XxxHelpers` は不可
- スコープ名は業務用語（`chronologically`, `latest`, `unread`）。`ordered_by_created_at` のような SQL 的な名前は避ける

## フロントエンド

- Hotwire（Turbo + Stimulus）のみ。React / Vue は使わない
- Stimulus コントローラーは単一責務・50行以内が目安
- 子要素のイベントは `data-action` で宣言する。要素が現れた時点で処理が要るなら `xxxTargetConnected()` を使う。`connect()` から子要素にバインド・参照しない（接続時点で子要素が未パースなことがあり、黙って失敗する）。`document` / `this.element` へのバインドは可
- ネイティブ CSS（`@layer`・ネスティング・カスタムプロパティ）。プリプロセッサ・Tailwind 不使用
- 標準パーシャルで組む。ViewComponent 不使用

## テスト

Minitest + fixtures。RSpec / factory_bot は使わない。fixture は最小限のデータで書く。

## 依存

新しい gem を入れる前に Rails 標準機能で解決できないか確認する。150行以内で自前実装できるなら入れない。

使わない gem: devise, pundit, cancancan, sidekiq, redis, view_component, GraphQL, factory_bot, rspec, Tailwind

## Ruby 構文

rubocop-rails-omakase が見ない範囲の慣習のみ:

- シンボル配列は角括弧内にスペース: `%i[ show edit update destroy ]`
- 複数条件は expression-less `case`（`case` の後に変数を置かない）
