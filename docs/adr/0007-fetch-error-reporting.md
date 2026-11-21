# 0007. フェッチ失敗は handled な警告として報告し、構造化イベントは JSON ログに出す

- 状態: 採用
- 記録日: 2026-11-21（元: `Feed::Fetching` / `config/initializers/structured_events.rb` のコメント）

## 背景

フィードのフェッチ失敗（ネットワークエラー、SSRF 検出、異常なレスポンス）は日常的に起こる、想定内のエラーである。一方で、どのフィードがどれくらい失敗しているかは追跡したい。

## 決定

- フェッチ失敗は `Rails.error.report(error, handled: true, severity: :warning, source: "feed.fetch")` で報告する。将来 Sentry などの subscriber を足せば、そのまま集計できる
- `Rails.error` にはデフォルトのロギング subscriber がない。そこで `Rails.logger.warn` も併記して、すぐ見えるようにしておく
- `Rails.event` にもデフォルトの subscriber がない。クロールのイベントは initializer で 1 行 JSON としてログに出し、grep でき、将来ログ転送もできる形にする
