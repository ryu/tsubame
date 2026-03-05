## アーキテクチャ方針

- **37signals コーディングスタイル準拠**
  - リッチドメインモデル（サービスオブジェクト不使用）
  - CRUDベースのコントローラー（7つの標準アクションのみ）
  - バニラRails（外部gem最小限）
  - Vanilla CSS（プリプロセッサなし）
- **シングルユーザー**: User モデルは認証用のみ。Subscription 中間テーブルなし
- **フィードパース**: Ruby 標準ライブラリ `rss` を使用（外部gem不使用）
- **concern 分割**: Feed は `Fetching`, `Autodiscovery`, `EntryImporter`, `Opml`、Entry は `RssParser` に分離
- **ファイルサイズ**: モデルの concern が200行を超えたら責務分割を検討する
