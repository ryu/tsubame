# マジックリンク認証 実装計画

## 概要

現行のパスワード認証（`has_secure_password`）をパスワードレス（マジックリンク）に移行する。
Rails 8 標準の `Authentication` concern（`start_new_session_for` / `terminate_session`）はそのまま活用し、認証フローのみを置き換える。

---

## データモデル変更

### 追加: `magic_links` テーブル

```ruby
create_table :magic_links, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true
  t.string :token_digest, null: false  # SHA-256 ハッシュ。生トークンは保存しない
  t.datetime :expires_at, null: false  # 有効期限（発行から15分）
  t.timestamps
end
add_index :magic_links, :token_digest, unique: true
```

### 変更: `users` テーブル

- `password_digest` を `null: true` に変更（既存ユーザーへの影響を避けつつ段階的に移行）

```ruby
change_column_null :users, :password_digest, true
```

---

## モデル

### `MagicLink`

```ruby
class MagicLink < ApplicationRecord
  belongs_to :user

  scope :valid, -> { where("expires_at > ?", Time.current) }

  def self.generate_for(user)
    token = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: digest(token), expires_at: 15.minutes.from_now)
    token  # 生トークンはメール送信にのみ使用。DB には保存しない
  end

  def self.find_by_token(token)
    valid.find_by(token_digest: digest(token))
  end

  class << self
    private

    def digest(token) = Digest::SHA256.hexdigest(token)
  end
end
```

### `User` モデル変更点

- `has_secure_password` を削除
- `password` バリデーションを削除
- `email_address` の `presence` / `uniqueness` バリデーションは維持

---

## コントローラー

### フロー概要

```
[1] GET  /session/new          メールアドレス入力フォーム
[2] POST /session              MagicLink 生成 → メール送信
[3] GET  /magic_links/:token   トークン検証 → セッション確立 → リダイレクト
```

### `SessionsController`

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "しばらく時間をおいてから試してください。" }

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])
    if user
      token = MagicLink.generate_for(user)
      MagicLinkMailer.with(user: user, token: token).magic_link_email.deliver_later
    end
    # ユーザーが存在しない場合も同じメッセージを返す（ユーザー列挙対策）
    redirect_to new_session_path, notice: "ログインリンクをメールで送信しました。"
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
```

### `MagicLinksController`

- `show` ではなく `create` 相当の操作（セッション確立）だが、メールリンクは GET で届くため `show` アクションで受ける
- 処理はセッションを作る副作用があることを意識する

```ruby
class MagicLinksController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    magic_link = MagicLink.find_by_token(params[:token])

    if magic_link
      magic_link.destroy!  # 使い捨て
      start_new_session_for magic_link.user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "リンクが無効または期限切れです。再度メールを送信してください。"
    end
  end
end
```

---

## メーラー

```ruby
class MagicLinkMailer < ApplicationMailer
  def magic_link_email
    @user = params[:user]
    @url = magic_link_url(params[:token])
    mail(to: @user.email_address, subject: "ログインリンク")
  end
end
```

---

## ルーティング

```ruby
resource :session, only: %i[ new create destroy ]
resources :magic_links, only: :show, param: :token
```

---

## セキュリティ考慮事項

| リスク | 対策 |
|---|---|
| トークン漏洩 | DBには SHA-256 ハッシュのみ保存。生トークンはメール経由のみ |
| トークン再利用 | 検証後に `destroy!`（使い捨て） |
| ブルートフォース | `rate_limit` で POST /session を制限 |
| ユーザー列挙 | ユーザー存在有無にかかわらず同一レスポンスを返す |
| 期限切れ | 有効期限15分、`valid` スコープで自動フィルタ |

---

## 実装ステップ

1. **Migration**: `magic_links` テーブル作成、`users.password_digest` を `null: true` に変更
2. **Model**: `MagicLink` モデル作成、`User` モデルからパスワード関連を削除
3. **Mailer**: `MagicLinkMailer` 作成、メールテンプレート作成
4. **Controller**: `SessionsController` 書き換え、`MagicLinksController` 新規作成
5. **Routes**: ルーティング更新
6. **Views**: ログインフォームをメールアドレス入力のみに変更
7. **Test**: 各レイヤーのテスト追加
8. **CI**: `bin/ci` を通してからマージ

---

## 未解決事項

- 既存ユーザーの `password_digest` は移行後に NULL にするか、そのまま残すか
- 期限切れ `magic_links` レコードの定期クリーンアップ（`CleanupEntriesJob` に相乗りするか別ジョブにするか）
