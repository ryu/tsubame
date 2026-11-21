# 0003. 新規タブを開く操作ではユーザーアクティベーションを保つ

- 状態: 採用
- 記録日: 2026-11-21（元: `keyboard_controller.js` / `pin_controller.js` / `lib/fetch_helper.js` のコメント）

## 背景

`v`（新規タブで開く）、`o`（ピン留めをまとめて開く）、`b` / `h`（はてなブックマーク）は `window.open` を呼ぶ。Safari 26 以降では、`window.open` がユーザーアクティベーションを持つ trusted なイベントの中から呼ばれないとポップアップとしてブロックされる。Stimulus の `dispatch()` が作る `CustomEvent` は `isTrusted=false` で、アクティベーションを引き継がない。

## 決定

- `keyboard_controller` は、新規タブを開くコマンド（`userActivationCommands`）だけ `dispatch` を経由させず、keydown ハンドラの中から対象コントローラーのメソッドを直接呼ぶ
- ピン留めをまとめて開く処理では、URL を `#pin_badge` の data 属性にあらかじめ描画しておく。サーバーに問い合わせずに、実際の URL で `window.open` を同期的に呼べるようにするためで、Safari は空 URL のポップアップもブロックする。開けたものだけをピン解除する
- バックグラウンドタブで開く処理（`openInBackground`）は Chrome / Firefox では動く。Safari では「新規タブ/ウインドウを開いたときにアクティブにする」をユーザーが設定でオフにしないと前面に出る。これはブラウザの仕様なので、アプリ側では対処しない

## 結果

- 直接呼ぶ経路でコントローラーが見つからない場合、ADR 作成時点では黙って何もしない。ryu/tsubame#114 で追跡している
