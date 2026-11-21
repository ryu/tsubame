# 0005. CSP nonce をセッションに保存する

- 状態: 採用
- 記録日: 2026-11-21（元: `config/initializers/content_security_policy.rb` / `test/integration/content_security_policy_test.rb` のコメント）

## 背景

import map や module preload のインラインスクリプト、Turbo のプログレスバー用 `<style>` には CSP nonce が必要になる。Rails の例では `session.id` から nonce を導出しているが、セッション cookie がまだない状態では `session.id` が nil になる。nonce が空だと source list 全体が無効になり、import map を含むすべてのインラインスクリプトがブロックされて、Stimulus が起動しない。

ログイン cookie は永続だがセッション cookie はそうではないので、翌日にブラウザを開いた最初のリクエストがちょうどこの状態になる。その結果、リロードするまでキーボードショートカットが効かなかった。

## 決定

- nonce はランダムに生成してセッションに保存し、以降のリクエストでも同じ値を使い続ける
- 同じ値を使い続ける理由: Turbo はページ間で中身が異なる head のスクリプトを再実行するが、再実行された import map は最初のページの nonce で評価されるため、値が変わると壊れる
- `img-src` は https の任意のホストを許可する。エントリ本文には、配信元フィードのホストにある画像が埋め込まれるため
- `connect-src` には、はてなブックマーク数を取得する API のホストを加える

## 結果

- セッション cookie なしのリクエストでも、空でない nonce が出ることをテストで固定している
