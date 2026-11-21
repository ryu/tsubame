# 0010. クロール系ジョブの書き込みを SQLite の単一ライターに合わせる

- 状態: 採用
- 記録日: 2026-11-21（元: `CleanupEntriesJob` / `FetchFeedJob` / `Feed` のコメント）

## 背景

SQLite は書き込みが 1 本しか通らないので、クロール・既読化・削除の書き込みはすべてそこに集中する（`docs/architecture.md`）。

## 決定

- `CleanupEntriesJob` は、保持期間を過ぎたエントリを `BATCH_SIZE` 件ずつ削除する。1 回の DELETE を小さく保って、書き込みロックを長く握らないようにするため。削除済みの行は対象から外れるので、途中で止まっても再実行すれば続きから処理され、再開用の状態は持たなくてよい
- `FetchFeedJob` は `limits_concurrency key: feed_id` を付ける。キューが詰まって `FetchFeedsJob` が同じフィードを二重に積んでも、並行してフェッチしないようにするため
- `next_fetch_at` は、フェッチ結果を記録する `record_successful_fetch!` / `record_fetch_error!` で明示的に設定する。`before_save` コールバックが動くのは `fetch_interval_minutes` が変わったとき（設定画面からの変更）だけにする
