# フィードクロール設計

## 概要

Solid Queue の recurring job でスケジューラを定期実行し、
各フィードのクロールを個別ジョブとして enqueue する。

## ジョブ構成

### FetchFeedsJob（スケジューラ）

- Solid Queue の recurring schedule で5分ごとに実行
- `next_fetch_at` が現在時刻以前のフィードを取得
- 各フィードに対して `FetchFeedJob` を enqueue

### FetchFeedJob（個別クロール）

薄いジョブクラス。`Feed#fetch` に委譲するのみ。

```ruby
Feed.find_by(id: feed_id)&.fetch
```

## Feed#fetch の処理フロー

フィードのクロールロジックは `Feed` モデルに実装されている。

```
1. HTTP GET リクエスト (Net::HTTP)
   - ETag があれば If-None-Match ヘッダーを付与
   - Last-Modified があれば If-Modified-Since ヘッダーを付与
   - 304 Not Modified → next_fetch_at のみ更新して終了

2. エンコーディング正規化
   - XML 宣言・HTTP ヘッダーからエンコーディングを検出
   - EUC-JP / Shift_JIS → UTF-8 に変換

3. レスポンスパース
   - Ruby 標準ライブラリ `rss` で RSS 1.0/2.0/Atom をパース
   - レスポンスヘッダーから ETag, Last-Modified を保存

4. エントリ登録
   - Entry.attributes_from_rss_item でRSSアイテムから属性を抽出
   - guid + feed_id で重複チェック
   - 新規エントリのみ作成

5. フィード更新
   - status: ok
   - last_fetched_at: 現在時刻
   - next_fetch_at: 現在時刻 + クロール間隔
   - etag, last_modified を保存

6. エラー時
   - status: error
   - error_message にエラー内容を記録
   - next_fetch_at: 現在時刻 + 30分（バックオフ）
```

## Entry.attributes_from_rss_item

RSS/Atom/RDF アイテムから属性ハッシュを生成するクラスメソッド。
guid が空の場合は nil を返す。

抽出項目: guid, title, url, author, body, published_at

- `content:encoded` が存在する場合は `description` より優先
- HTML タグをストリップしてタイトルを正規化

## セキュリティ (SSRF 防御)

- フェッチ前に URL のホストを DNS 解決し、プライベート IP (10.x, 172.16-31.x, 192.168.x, 127.x, ::1 等) を拒否
- リダイレクト先も同様にチェック
- レスポンスサイズ上限: 5MB

## クロール間隔

- フィードごとに設定可能（デフォルト: 10分）
- プリセット: 10分 / 30分 / 1時間 / 3時間 / 6時間 / 12時間 / 24時間
- エラー時: 一律30分（バックオフ）
- フィード編集画面で変更可能

## HTTP クライアント

`Net::HTTP` (Ruby 標準ライブラリ) を使用。

- タイムアウト: open 10秒、read 30秒
- リダイレクト: 最大5回まで追従
- User-Agent: "Tsubame/1.0"

## エントリ自動削除

### CleanupEntriesJob

- Solid Queue の recurring schedule で日次実行（午前3時）
- 条件: `read_at` が90日以上前 AND `pinned = false`
- 対象エントリを削除
