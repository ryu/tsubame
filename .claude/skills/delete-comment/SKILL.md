---
name: delete-comment
description: tsubame のコードコメントを棚卸しして削除する。各コメントを Tautology / Excuse / Stale / Decision Record に分類し、削除・イシュー登録・ADR への移動を行ってから、コメント禁止ラチェット（bin/lint-comments）のベースラインを下げる。/delete-comment を実行したとき、またはコメントの整理・削減を依頼されたときに使う。引数でファイルやディレクトリを指定すると対象を絞る。
---

# /delete-comment

コメントを書かない方針（[docs/adr/0001-no-code-comments.md](../../../docs/adr/0001-no-code-comments.md)）に向けて、残っているコメントを減らす。

## 1. 対象を決める

```bash
bin/lint-comments --list                 # 残っているコメントを「パス:行: 本文」で一覧する
cat config/comment_ratchet.yml           # ファイルごとの残数
```

引数があればそのパスに絞る。なければ、`config/comment_ratchet.yml` のうち手書きのファイルから着手する。Rails / Kamal のジェネレータが出力した設定ファイル（`config/environments/*.rb`、`config/puma.rb`、`config/deploy.yml`、`Dockerfile`、`Gemfile` など）は、ジェネレータの雛形と比べて**追記された行だけ**を判断対象にする。

## 2. 分類する

コメントごとに、前後のコードと関連テストを読んでから分類する。

| 分類 | 判定基準 | 例 |
|---|---|---|
| **Tautology** | コードを読めば分かることの言い直し。セクション見出しやジェネレータの説明文も含む | `# Skip if IME is composing`、`/* Entry list */` |
| **Stale** | 今の実装と食い違う。コメントアウトされたコードや、使っていない雛形も含む | インデックス保持時代のカーソルの説明、`# get "manifest" => ...` |
| **Excuse** | 手抜きの実装（握りつぶし・黙ったスキップ・一時しのぎ）を正当化している | 「その他のエラーは候補なし扱い」「見つからなければスキップ」「直ったら消す」 |
| **Decision Record** | コードからは読み取れない「なぜ」。外部仕様、過去の不具合、トレードオフ | Safari のユーザーアクティベーション、CSP nonce の保存先 |

迷ったときの判断:

- 「この行を消したら、次に触る人が同じ罠にはまるか？」→ はまるなら Decision Record、はまらないなら Tautology
- 「このコメントがなければ、この実装はレビューを通るか？」→ 通らないなら Excuse
- Decision Record がすでに `docs/*.md` や `.claude/rules/` に書かれていれば、ADR には重複させずに削除だけする

## 3. 分類ごとに対応する

- **Tautology / Stale**: 削除する。名前で意図が伝わらないときは、コメントを足す代わりに変数やメソッドを抽出して名前を付ける
- **Excuse**: 削除し、`gh issue create --label bug`（機能不足なら `enhancement`）でイシューを登録する。本文には次を書く
  - 元のコメントの引用と、`path:line`（削除前の行番号）
  - その手抜きで起きる具体的な症状（入力 → 誤った結果）
  - 直し方の候補
  - 同じ PR では直さない（範囲を広げない）。直すなら別 PR にする
- **Decision Record**: `docs/adr/` に ADR を追加するか、既存の ADR に追記してから削除する。形式と番号の付け方は [docs/adr/README.md](../../../docs/adr/README.md) に従い、README の一覧表も更新する。記録日は作業した日付にして、元のコメントがあった場所を併記する

## 4. 削除する

- 行全体がコメントなら、その行を消す。行末コメントなら、コメントと直前の空白だけを消す
- 消した結果、空行が連続したら 1 行に詰める
- 次のものは消さない（lint の対象外でもある）: shebang、`frozen_string_literal` などのマジックコメント、`rubocop:disable`、ERB の `<%# locals: ... %>`、Dockerfile の `# syntax=` / `# check=`
- テストの説明コメントが消えて意図が読めなくなる場合は、`test "..."` の名前を具体的にする

## 5. ラチェットを下げて検証する

```bash
bin/rubocop -a                 # 削除で残った空行を直す
bin/lint-comments --update     # ベースラインを下げる（下げる方向にしか動かない）
git diff config/comment_ratchet.yml   # 数が減っただけで、増えたファイルがないことを確かめる
bin/ci                         # 全部パスさせる
```

`git diff -U0 | grep '^-' | grep -vE '^-\s*(#|//|/\*|\*|<%#|<!--|$)'` で、コメント以外の行を消していないかも確認する（行末コメントを消した行だけが出るはず）。

## 6. 報告する

PR の本文とユーザーへの報告には、次を含める。

- 分類ごとの件数と削除した行数
- 登録したイシューの番号
- 追加・追記した ADR
- 今回扱わずにベースラインに残した範囲と、その理由
