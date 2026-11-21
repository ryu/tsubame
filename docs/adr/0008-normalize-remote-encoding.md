# 0008. リモート由来のテキストを UTF-8 に正規化する

- 状態: 採用
- 記録日: 2026-11-21（元: `Feed::Fetching` / `Feed::Opml` のコメント）

## 決定

- フィード本文は UTF-8 に変換したうえで、XML 宣言の `encoding=` も必ず `"UTF-8"` に書き換える。宣言と実際のエンコーディングが食い違うと、REXML が `ArgumentError` を投げるため
- HTTP ヘッダや XML 宣言から得た charset は、リモートが送ってくる任意の文字列なので、Ruby が知らない名前のこともある。`Encoding.find` が失敗したら nil を返し、自動判定にフォールバックする
- OPML は、アップロードされたファイルなら ASCII-8BIT、`File.read` なら UTF-8 で渡ってくる。どちらでも BOM 除去が同じ結果になるよう、先に UTF-8 に揃えて `scrub` する
