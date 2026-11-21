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

- 入力 URL のサイトに接続できない（`Feed::Fetching::NETWORK_ERRORS`）ときは、`Feed::UnreachableError` を投げて登録せず、フォームを 422 で再表示する。以前は候補なしとして扱い、HTML ページの URL でもそのまま登録していた（ryu/tsubame#113）
- URL として解釈できないときは候補なしとして扱い、`Feed` のバリデーションでエラーにする。それ以外の想定外の例外は握りつぶさない
