# Architecture Decision Records

コードからは読み取れない判断を記録する。コードコメントは書かず、ここに書く（[0001](0001-no-code-comments.md)）。

新しい ADR は、連番の次の番号で `NNNN-kebab-case-title.md` として追加する。項目は「状態 / 記録日 / 背景 / 決定 / 結果」で、不要な項目は省いてよい。判断を覆すときは、元の ADR を消さずに状態を「廃止（NNNN で置き換え）」に変える。

| # | タイトル |
|---|---|
| [0001](0001-no-code-comments.md) | コードコメントを書かない |
| [0002](0002-derive-selection-cursor.md) | キーボード選択カーソルを保存せず DOM から導出する |
| [0003](0003-user-activation-for-new-tabs.md) | 新規タブを開く操作ではユーザーアクティベーションを保つ |
| [0004](0004-refresh-requester-after-mark-as-read.md) | 既読化後の refresh を要求元クライアントにも届ける |
| [0005](0005-csp-nonce-in-session.md) | CSP nonce をセッションに保存する |
| [0006](0006-subscribe-race.md) | フィード購読時の URL 競合は既存レコードで購読し直す |
| [0007](0007-fetch-error-reporting.md) | フェッチ失敗は handled な警告として報告し、構造化イベントは JSON ログに出す |
| [0008](0008-normalize-remote-encoding.md) | リモート由来のテキストを UTF-8 に正規化する |
| [0009](0009-autodiscovery-scope.md) | オートディスカバリの探索範囲 |
| [0010](0010-crawl-write-load.md) | クロール系ジョブの書き込みを SQLite の単一ライターに合わせる |
| [0011](0011-magic-link-lifecycle.md) | マジックリンクの消費タイミングと有効期限 |
| [0012](0012-entry-url-sanitize.md) | エントリの URL は http(s) のみ通す |
| [0013](0013-hatena-count-single-queue.md) | はてなブックマーク数の取得は 1 段のキューにまとめる |
| [0014](0014-system-tests-real-flow.md) | System test は本番と同じ CSRF と認証の経路を通す |

既存の設計ドキュメントにすでに書かれていた判断は、ADR には重複させていない。SSRF の 2 層防御は `docs/feed_crawling.md`、重複エントリの既読同期でピン状態を上書きしないことは `docs/entry_dedup_design.md`、バックアップスクリプトのセットアップ手順は `docs/backup.md` にある。
