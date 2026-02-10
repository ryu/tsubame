# フィードクロール設計

## 概要

Solid Queue の recurring job でスケジューラを定期実行し、
各フィードのクロールを個別ジョブとして enqueue する。

## ジョブ構成

### FetchFeedsJob（スケジューラ）

- Solid Queue の recurring schedule で数分ごとに実行
- `next_fetch_at` が現在時刻以前のフィードを取得
- 各フィードに対して `FetchFeedJob` を enqueue

### FetchFeedJob（個別クロール）

1 フィードのクロールを実行する。

```
1. HTTP GET リクエスト
   - ETag があれば If-None-Match ヘッダーを付与
   - Last-Modified があれば If-Modified-Since ヘッダーを付与
   - 304 Not Modified → next_fetch_at のみ更新して終了

2. レスポンスパース
   - Ruby 標準ライブラリ `rss` で RSS 1.0/2.0/Atom をパース
   - レスポンスヘッダーから ETag, Last-Modified を保存

3. エントリ登録
   - guid で重複チェック (upsert)
   - 新規エントリのみ作成

4. フィード更新
   - status: ok
   - last_fetched_at: 現在時刻
   - next_fetch_at: 現在時刻 + クロール間隔
   - etag, last_modified を保存

5. エラー時
   - status: error
   - error_message にエラー内容を記録
   - next_fetch_at は設定（リトライ間隔を長めに）
```

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

- Solid Queue の recurring schedule で日次実行
- 条件: `read_at` が90日以上前 AND `pinned = false`
- 対象エントリを削除
