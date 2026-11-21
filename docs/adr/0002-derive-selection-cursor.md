# 0002. キーボード選択カーソルを保存せず DOM から導出する

- 状態: 採用
- 記録日: 2026-11-21（元: `entry_list_controller.js` / `feed_list_controller.js` / `test/system/entry_cursor_test.rb` のコメント）

## 背景

フィード一覧・エントリ一覧の「いま選択中の行」は、以前はインデックスを保存していた。これには 2 つの問題があった。

- エントリ一覧: Turbo Frame の読み込みで一覧が差し替わっても、保存したインデックスは古いまま残る。`turbo:frame-load` は新しいエントリが DOM に入った**後**に届くため、その間にキーを押すと古いカーソルを読み、移動しない・選択が消えるといった症状が出た（`p` / `k` / `b` が無反応になる）
- フィード一覧: morph による refresh でペインが再描画されると、保存したインデックスは同じ位置に移ってきた別のフィードを指してしまう

## 決定

保存するのは選択中の要素の ID（`activeId`）だけにする。`activeIndex` は毎回 `items.findIndex(...)` で求める getter にする。

## 結果

- 再読み込み後に選択中の要素が一覧に残っていればカーソルも残り、消えていればカーソルも外れる（-1）。どちらも `test/system/entry_cursor_test.rb` で固定している
- フィードを切り替えるとカーソルは自然にリセットされる（`test/system/feed_navigation_test.rb`）
- Stimulus の `connect()` 時点では子要素がまだパースされていないことがあるため、要素の出現に反応する処理は `xxxTargetConnected()` に置く（`.claude/rules/dhh_style.md` のフロントエンド節と同じ理由）
