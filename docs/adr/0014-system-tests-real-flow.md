# 0014. System test は本番と同じ CSRF と認証の経路を通す

- 状態: 採用
- 記録日: 2026-11-21（元: `test/application_system_test_case.rb` / `config/ci.rb` のコメント）

## 決定

- test 環境では forgery protection が無効なので、`csrf_meta_tags` が空になり、`fetchWithCsrf` が実際の挙動を再現できない。System test では setup で `allow_forgery_protection = true` にし、teardown で元に戻す
- ログインには本物のマジックリンクのフローを使う。このアプリにパスワード認証はない
- System test はヘッドレス Chrome で動くので、`bin/ci` をローカルで実行するには Chrome が必要
- System test は、Stimulus の outlet の配線ミスのように「黙って壊れる」箇所をエンドツーエンドで固定するために書く

## 結果

- Capybara 3.40.0 はセッションをリセットするときに `Storage.clearDataForOrigin(origin: "*")` を送り、最近の Chrome はこれを拒否する。そこで `ClearStorageForAppOrigin` を prepend して、アプリサーバーの origin を指定させている。上流の修正（teamcapybara/capybara#2865）がリリースされるまでの暫定措置
- Capybara が 3.40.0 より新しくなると、`ClearStorageForAppOrigin.verify_still_needed!` が System test の起動時に例外を投げる。Dependabot の更新 PR で、パッチを外すか対象バージョンを上げるかを必ず判断することになる（ryu/tsubame#115）
