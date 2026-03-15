# データモデル定義

## Feed

フィード（RSS/Atom）のグローバル共有リソース。同じURLのフィードは1つだけ存在する。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| url | string | フィードURL (unique, not null) |
| title | string | フィードタイトル |
| site_url | string | サイト本体のURL |
| description | text | フィードの説明 |
| fetch_interval_minutes | integer | クロール間隔（分）(default: 10, not null) |
| last_fetched_at | datetime | 最終クロール日時 |
| next_fetch_at | datetime | 次回クロール予定日時 |
| status | integer | enum: ok(0), error(1) (default: 0, not null) |
| error_message | text | 直近のエラーメッセージ |
| etag | string | HTTP ETag ヘッダーの値 |
| last_modified | string | HTTP Last-Modified ヘッダーの値 |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_feeds_on_url` (unique)
- `index_feeds_on_next_fetch_at`

## Entry

フィードの個別エントリ（記事）。グローバル共有リソース。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| feed_id | integer | FK → feeds.id (not null) |
| guid | string | フィード内の一意識別子 (not null) |
| title | string | エントリタイトル |
| url | string | パーマリンク |
| author | string | 著者 |
| body | text | 本文 (HTML) |
| published_at | datetime | 公開日時 |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_entries_on_feed_id`
- `index_entries_on_feed_id_and_guid` (unique)
- `index_entries_on_published_at`

## Subscription

ユーザーとフィードの中間テーブル。フォルダ・レート・カスタムタイトルを管理する。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| user_id | integer | FK → users.id (not null) |
| feed_id | integer | FK → feeds.id (not null) |
| folder_id | integer | FK → folders.id |
| title | string | ユーザーが設定したカスタムタイトル (nil = feed.title を使用) |
| rate | integer | レート 0〜5 (default: 0, not null) |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_subscriptions_on_user_id_and_feed_id` (unique)
- `index_subscriptions_on_user_id_and_folder_id`
- `index_subscriptions_on_feed_id`

## UserEntryState

ユーザーごとの既読・ピン状態。行が存在しない場合は未読・未ピンとして扱う。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| user_id | integer | FK → users.id (not null) |
| entry_id | integer | FK → entries.id (not null) |
| read_at | datetime | 既読日時 (null = 未読) |
| pinned | boolean | ピン状態 (default: false, not null) |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_user_entry_states_on_user_id_and_entry_id` (unique)
- `index_user_entry_states_on_user_id_and_pinned`
- `index_user_entry_states_on_user_id_and_read_at`

## Folder

フォルダによるフィード分類。ユーザーごとに管理。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| user_id | integer | FK → users.id (not null) |
| name | string | フォルダ名 (not null, max 50) |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_folders_on_user_id_and_name` (unique)

## User

認証・購読管理。Rails 8 の `bin/rails generate authentication` で生成されるスキーマに準拠。

## Session

認証セッション管理。Rails 8 の authentication generator で生成。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| user_id | integer | FK → users.id (not null) |
| ip_address | string | ログイン元 IP |
| user_agent | string | ブラウザ User-Agent |
| created_at | datetime | |
| updated_at | datetime | |

## エントリのライフサイクル

```
クロール → Entry作成（グローバル共有）
  → ユーザーが閲覧 → UserEntryState.read_at に日時セット
  → 90日経過 & 誰もピン留めしていない → CleanupEntriesJob で自動削除
```

## データモデルの設計方針

- Feed/Entry はグローバル共有（同じフィードは1回だけフェッチ）
- Subscription がユーザーとフィードを紐付ける（Fastladder互換パターン）
- 既読/ピン状態は UserEntryState で管理（行なし＝未読・未ピン）
