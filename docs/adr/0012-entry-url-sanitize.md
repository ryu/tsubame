# 0012. エントリの URL は http(s) のみ通す

- 状態: 採用
- 記録日: 2026-11-21（元: `Entry#safe_url_for_link` / `entry_test.rb` のコメント）

## 決定

エントリの URL は、`link_to` の href と `window.open` にそのまま渡される。そこで `Entry#safe_url_for_link` は、http / https 以外のスキーム（`javascript:` など）や空の URL に対して nil を返す。フィードは任意の第三者が配信するものなので、URL は信頼しない。
