# マジックリンク認証

パスワードは使わず、メールで届くワンタイムリンクでログインする。v3.0.0（2026-04-18）でパスワード認証から移行し、`users.password_digest` は削除済み。

Rails 8 の `bin/rails generate authentication` が生成した `Authentication` concern（`start_new_session_for` / `terminate_session`）はそのまま使い、セッションを作るまでの流れだけを置き換えている。

## フロー

```
[1] GET  /session/new                            メールアドレス入力フォーム（SessionsController#new）
[2] POST /session                                MagicLink を生成してメールを送る（SessionsController#create）
[3] GET  /magic_links/:token                     確認ページ。トークンは消費しない（MagicLinksController#show）
[4] POST /magic_links/:token/consumption         トークンを検証・消費してセッションを作る（MagicLinkConsumptionsController#create）
```

- [3] でトークンを消費しないのは、メールスキャナやセキュリティプロキシがリンクを先読みしても、ユーザーがクリックする前にトークンが使われないようにするため（[ADR 0011](adr/0011-magic-link-lifecycle.md)）。セッションを作るのは、ユーザーが確認ページのボタンを押したときの POST だけ
- トークンの消費は「消費というリソースを作る」と捉えて、`resource :consumption, only: :create` にしている（CRUD のみのコントローラーという方針に従う）
- メールは `deliver_later` で送るため、送信の失敗はリクエストではなくジョブ側で起きる

## データ

`magic_links` テーブル: `user_id` / `token_digest`（unique）/ `expires_at`

- DB に保存するのは SHA-256 のダイジェストだけ。生のトークンはメールの URL にしか現れない
- 有効期限は発行から 15 分。`MagicLink.valid` スコープで絞り込む。Range で書いているため、期限ちょうどのリンクはまだ有効として扱う
- `MagicLink.generate_for(user)` は、そのユーザーの既存のリンクをすべて削除してから新しいリンクを発行する。再送しても有効なトークンは増えず、1 ユーザーあたりのレコードは常に 1 件以下に保たれる

## セキュリティ

| リスク | 対策 |
|---|---|
| トークン漏洩 | DB にはダイジェストのみ保存する |
| トークン再利用 | 消費時に `destroy!` する（使い捨て） |
| リンクの先読み | GET では消費せず、POST でのみ消費する |
| 再送でトークンが増える | 発行時に同じユーザーの既存リンクを削除する |
| ブルートフォース・メール爆撃 | `POST /session` を IP ごと（3 分 10 回）とメールアドレスごと（10 分 3 回）に `rate_limit` で制限する |
| ユーザー列挙 | ユーザーがいてもいなくても、同じレスポンスを返す |
| 期限切れ | 15 分で失効する |

## テスト

- `test/models/magic_link_test.rb`: ダイジェスト保存、有効期限、再発行時の置き換え、期限境界
- `test/controllers/magic_links_controller_test.rb`: 確認ページでは消費しないこと、POST での消費とセッション確立、無効・期限切れのトークン
- System test は本物のマジックリンクフローでログインする（[ADR 0014](adr/0014-system-tests-real-flow.md)）

## 今後の作業

優先度順。

### 1. `MagicLinkMailer` の単体テスト追加（優先度: 中）

`test/mailers/magic_link_mailer_test.rb` を追加し、本文に確認ページの URL が含まれること、件名と宛先が正しいことを確認する。

### 2. `find_by_token` のリネーム検討（優先度: 低）

`MagicLink.find_by_token` は Rails の動的ファインダ（`find_by_カラム名`）と名前が紛らわしい。クラスメソッドで明示的に定義しているので、動作には問題はない。

候補名: `authenticate_by_token`、`valid_for`

### 3. メーラー設定の環境変数化（優先度: 低）

`ApplicationMailer` の `from` がドメインの直書きで、開発環境でも同じドメインが使われる。`ENV.fetch("MAIL_FROM", ...)` にすれば、環境ごとに切り替えられる。

### 4. メール配送失敗の検知（優先度: 低）

`deliver_later` なので、Resend 側が障害を起こしてもログイン画面は「送信しました」と表示する。ユーザー列挙対策のため、画面表示はこのままでよい。ただし、ジョブの失敗を運用側で気付ける手段（Mission Control の失敗ジョブ確認など）を決めておく。
