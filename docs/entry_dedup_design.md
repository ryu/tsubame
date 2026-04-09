# エントリ重複排除 設計書

## 概要

同じ記事が複数フィードに掲載された場合（例: ブログRSS + アグリゲーターフィード）、一方を既読にすると同一URLを持つ他のエントリも自動的に既読にする。

## スコープ

- **対象**: 既読状態の同期のみ
- **対象外**: ピン状態の同期（各エントリ独立のまま）

## アプローチ

`entries` テーブルに `content_url`（正規化URL）カラムを追加し、同じ `content_url` を持つエントリを重複とみなす。エントリを既読にした際、重複エントリにも `UserEntryState` を即座に作成することで、既存の未読カウントクエリ (`with_unread_count`) を変更せずに正しい結果を返す。

## URL 正規化ルール

| ルール | 例 |
|---|---|
| `utm_*` パラメータ除去 | `?utm_source=twitter&id=1` → `?id=1` |
| `fbclid` パラメータ除去 | `?fbclid=abc` → パラメータなし |
| `gclid` パラメータ除去 | `?gclid=abc` → パラメータなし |
| フラグメント除去 | `#section1` → 除去 |
| 末尾スラッシュ除去 | `/path/` → `/path` |
| スキームは維持 | `http://` と `https://` は別URL扱い |
| NULL/非HTTP → nil | 重複排除対象外 |

## DB スキーマ変更

### マイグレーション 1: `content_url` カラム追加

```ruby
class AddContentUrlToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :content_url, :string
    add_index :entries, :content_url
  end
end
```

### マイグレーション 2: 既存データのバックフィル

```ruby
class BackfillContentUrlOnEntries < ActiveRecord::Migration[8.1]
  def up
    Entry.in_batches(of: 1000) do |batch|
      batch.each do |entry|
        normalized = Entry.normalize_url(entry.url)
        entry.update_column(:content_url, normalized) if normalized.present?
      end
    end
  end

  def down
    Entry.update_all(content_url: nil)
  end
end
```

## モデル変更

### `app/models/entry.rb`

追加内容:

- `before_save :set_content_url, if: :url_changed?` コールバック
- `scope :duplicates_of` — 同じ `content_url` を持つ他のエントリを返す（`content_url` が nil の場合は `none` を返す）
- `self.normalize_url(raw_url)` クラスメソッド — URL正規化ロジック
- `set_content_url` private メソッド

```ruby
before_save :set_content_url, if: :url_changed?

scope :duplicates_of, ->(entry) {
  return none if entry.content_url.blank?
  where(content_url: entry.content_url).where.not(id: entry.id)
}

def self.normalize_url(raw_url)
  return nil if raw_url.blank?

  uri = URI.parse(raw_url)
  return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

  if uri.query.present?
    cleaned_params = URI.decode_www_form(uri.query).reject do |key, _|
      key.match?(/\Autm_/i) || %w[fbclid gclid].include?(key.downcase)
    end
    uri.query = cleaned_params.empty? ? nil : URI.encode_www_form(cleaned_params)
  end

  uri.fragment = nil
  uri.path = uri.path.chomp("/") if uri.path.length > 1

  uri.to_s
rescue URI::InvalidURIError
  nil
end

private

def set_content_url
  self.content_url = self.class.normalize_url(url)
end
```

### `app/models/user.rb`

#### `mark_entry_as_read!` 変更

既読後に `sync_read_state_to_duplicates!` を呼び出す。

```ruby
def mark_entry_as_read!(entry)
  state = entry_state_for(entry)
  return false if state.read_at.present?

  now = Time.current
  state.update!(read_at: now)
  sync_read_state_to_duplicates!(entry, now)
  true
end
```

#### `mark_feed_entries_as_read!` 変更

既存の `upsert_all` に `update_only: [:read_at, :updated_at]` を追加（既存バグ修正）。重複エントリへの既読同期を追加。

```ruby
def mark_feed_entries_as_read!(feed)
  unread_entry_ids = feed.entries
    .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
    .pluck(:id)

  return 0 if unread_entry_ids.empty?

  now = Time.current
  records = unread_entry_ids.map do |entry_id|
    { user_id: id, entry_id: entry_id, read_at: now, created_at: now, updated_at: now }
  end
  UserEntryState.upsert_all(records, unique_by: [:user_id, :entry_id], update_only: [:read_at, :updated_at])

  # 重複エントリの既読同期
  content_urls = Entry.where(id: unread_entry_ids).where.not(content_url: nil).pluck(:content_url).uniq
  if content_urls.any?
    duplicate_entry_ids = Entry.where(content_url: content_urls)
      .where.not(id: unread_entry_ids)
      .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
      .pluck(:id)

    if duplicate_entry_ids.any?
      dup_records = duplicate_entry_ids.map do |entry_id|
        { user_id: id, entry_id: entry_id, read_at: now, created_at: now, updated_at: now }
      end
      UserEntryState.upsert_all(dup_records, unique_by: [:user_id, :entry_id], update_only: [:read_at, :updated_at])
    end
  end

  unread_entry_ids.size
end
```

#### `sync_read_state_to_duplicates!` 新規 private メソッド

```ruby
private

def sync_read_state_to_duplicates!(entry, read_at)
  return if entry.content_url.blank?

  duplicate_ids = Entry.duplicates_of(entry)
    .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
    .pluck(:id)

  return if duplicate_ids.empty?

  records = duplicate_ids.map do |entry_id|
    { user_id: id, entry_id: entry_id, read_at: read_at, created_at: read_at, updated_at: read_at }
  end
  UserEntryState.upsert_all(records, unique_by: [:user_id, :entry_id], update_only: [:read_at, :updated_at])
end
```

## 変更不要なファイル

| ファイル | 理由 |
|---|---|
| `app/models/feed/entry_importer.rb` | `before_save` コールバックで自動設定 |
| `app/models/user_entry_state.rb` | 変更なし |
| `app/models/subscription.rb` | `with_unread_count` 変更なし（既読同期で担保） |
| 全コントローラー | モデル内のロジックで完結 |
| 全ビュー | 変更なし |
| JavaScript | 変更なし |
| `config/routes.rb` | 変更なし |

## Rake タスク: 既存重複の遡及同期

`lib/tasks/sync_duplicate_read_states.rake`

既存データに対して、同一 `content_url` を持つエントリ間で既読状態を遡及的に同期する。

```bash
bin/rails entries:sync_duplicate_read_states
```

## テスト

### フィクスチャ追加

- `test/fixtures/feeds.yml` — アグリゲーターフィード追加
- `test/fixtures/entries.yml` — 重複エントリ追加（既存エントリと同一URLを持つ別フィードのエントリ）
- `test/fixtures/subscriptions.yml` — アグリゲーター購読追加

### テスト追加

- `test/models/entry_test.rb` — `normalize_url` / `before_save` / `duplicates_of` のテスト
- `test/models/user_test.rb` — 既読同期のテスト（ピン状態が保護されることの確認を含む）
- `test/controllers/entry_mark_as_reads_controller_test.rb` — 重複同期の統合テスト
- `test/controllers/feed_mark_as_reads_controller_test.rb` — 一括既読の重複同期テスト

## エッジケース

| ケース | 動作 |
|---|---|
| `url` が NULL | `content_url` も NULL → 重複排除対象外 |
| `url` が非HTTP | `content_url` が NULL → 重複排除対象外 |
| 不正なURI | `content_url` が NULL → 重複排除対象外 |
| 既に既読の重複エントリ | `where.not(read_at: nil)` で除外。余計な upsert なし |
| ピン留め済みの重複エントリ | `update_only: [:read_at, :updated_at]` により `pinned` は上書きされない |
| 購読していないフィードの重複 | `UserEntryState` は作成される。`with_unread_count` は購読フィードのみカウントするため UI に影響なし |

## `upsert_all` の安全性

全ての `upsert_all` 呼び出しで `update_only: [:read_at, :updated_at]` を指定。これにより:
- 既存の `pinned` カラムは上書きされない
- `read_at` が既にセットされている行は `read_at` が更新されるだけ（害なし）

## ステータス

- 設計: 完了（レビュー承認済み）
- 実装: 未着手
