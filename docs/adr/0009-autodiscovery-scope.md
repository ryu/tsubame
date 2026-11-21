# 0009. オートディスカバリの探索範囲

- 状態: 採用
- 記録日: 2026-11-21（元: `Feed::Autodiscovery` / `Feed::Subscribable` のコメント）

## 決定

- 入力 URL のレスポンスがフィードの Content-Type なら、その URL を候補にする。HTML なら `<head>` 内の `<link rel="alternate" type="application/(rss|atom)+xml">` を探す
- 見るのは `<link>` だけなので、本文は先頭 `MAX_HTML_PROBE_SIZE` バイトで読み込みを打ち切り、`</head>` までに切り詰める
- `<link>` の属性の順序は問わない（`type` が先で `rel` が後のサイトもある）
- `<link>` が見つからないときは、よくあるフィードのパス（`/feed`、`/rss.xml` など）に短いタイムアウトで HEAD を送り、Content-Type で判定する
- 候補が 0 件なら入力 URL をそのまま、1 件ならその URL を `Feed` として購読する。複数あればユーザーに選ばせる
- SSRF の検出（`Feed::SsrfError`）は握りつぶさずに、呼び出し元まで伝える

## 結果

- ADR 作成時点では、オートディスカバリがネットワークエラーで失敗すると候補なしとして扱い、入力 URL をそのまま登録する。ryu/tsubame#113 で見直している
