# データモデル定義

## Feed

フィード（RSS/Atom）の購読情報。

| カラム | 型 | 説明 |
|--------|------|------|
| id | integer | PK |
| url | string | フィードURL (unique, not null) |
| title | string | フィードタイトル |
| site_url | string | サイト本体のURL |
| description | text | フィードの説明 |
| last_fetched_at | datetime | 最終クロール日時 |
| next_fetch_at | datetime | 次回クロール予定日時 |
| status | integer | enum: ok(0), error(1) |
| error_message | text | 直近のエラーメッセージ |
| etag | string | HTTP ETag ヘッダーの値 |
| last_modified | string | HTTP Last-Modified ヘッダーの値 |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_feeds_on_url` (unique)
- `index_feeds_on_next_fetch_at`

## Entry

フィードの個別エントリ（記事）。

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
| read_at | datetime | 既読日時 (null=未読) |
| pinned | boolean | ピン状態 (default: false) |
| created_at | datetime | |
| updated_at | datetime | |

### インデックス

- `index_entries_on_feed_id`
- `index_entries_on_guid` (unique)
- `index_entries_on_read_at`
- `index_entries_on_pinned`
- `index_entries_on_published_at`

## User

認証用。シングルユーザーのため seed で 1 レコードのみ作成。

Rails 8 の `bin/rails generate authentication` で生成されるスキーマに準拠。

## エントリのライフサイクル

```
クロール → Entry作成 (read_at: nil)
  → ユーザーが閲覧 → read_at に日時セット
  → 90日経過 & 既読 → 自動削除ジョブで削除
  ※ ピン付きエントリは削除対象外
```
