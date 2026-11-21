# 0004. 既読化後の refresh を要求元クライアントにも届ける

- 状態: 採用
- 記録日: 2026-11-21（元: `EntryMarkAsReadsController` / `FeedMarkAsReadsController` のコメント）

## 背景

`turbo_stream.refresh` は、デフォルトでは現在のリクエストの `request_id` を付けて送られる。Turbo は自分が出したリクエストの refresh を無視するので、既読化を要求したタブ自身は画面が更新されない。

## 決定

既読化のレスポンスでは `turbo_stream.refresh(request_id: nil)` を返し、要求元も morph で再描画させる。

## 結果

- 「すべて既読」を実行したタブで、未読のなくなったフィードがペインから消え、エントリ一覧の Frame が `src` から読み直される（`test/system/mark_all_as_read_test.rb`）
