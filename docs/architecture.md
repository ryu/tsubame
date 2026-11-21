# アーキテクチャ概要

## システム構成

```
さくらのVPS (Kamal)
├── Puma (Web)
│   └── Solid Queue Supervisor (in-process)
├── SQLite3 (WAL mode)
│   ├── primary (アプリデータ)
│   ├── queue (Solid Queue)
│   ├── cache (Solid Cache)
│   └── cable (Solid Cable)
└── Thruster (HTTP proxy, SSL, asset caching)
```

- シングルユーザー、シングルサーバー構成
- Solid Queue は Puma プロセス内で実行 (SOLID_QUEUE_IN_PUMA=true)
- SQLite3 は WAL mode で並行読み書きに対応

### シングルユーザー前提の設計判断

データモデル（User / Subscription / UserEntryState / Admin）は複数ユーザーを許容する形だが、
運用はシングルユーザー前提であり、以下は既知のトレードオフとして許容する:

- `feeds.fetch_interval_minutes` はグローバル設定（購読者ごとに変えられない）
- ピン留めされたエントリーは保持期間を過ぎても削除されない（CleanupEntriesJob が除外）
- SQLite の単一ライターにクロール・既読化・削除の書き込みが集中する

複数ユーザー運用へ本格移行する場合は、フェッチ間隔の Subscription への移動、
未読数集計のキャッシュ、Postgres 移行を再検討すること。

## フロントエンド

Hotwire (Turbo + Stimulus) + Vanilla CSS による SPA ライクな操作感。

### 3ペインレイアウト

```
┌──────────┬─────────────────────────┐
│          │  Entry List             │
│  Feeds   │  (Turbo Frame)         │
│  (左)    ├─────────────────────────┤
│          │  Entry Content          │
│          │  (Turbo Frame)         │
└──────────┴─────────────────────────┘
```

- 左ペイン: フィード一覧（未読数表示）
- 右上ペイン: エントリ一覧
- 右下ペイン: エントリ本文

### Stimulus の責務分担

キーボード操作は「入力の受け口」と「操作の実行先」を分けている。配線は `app/views/home/index.html.erb` の `data-action` に集まっている。

- `keyboard_controller` — keydown のルーター。キーをコマンドに変換して `keyboard:*` イベントを dispatch するだけで、操作自体は行わない。新規タブを開くコマンドだけは dispatch せず、対象コントローラーのメソッドを直接呼ぶ（[ADR 0003](adr/0003-user-activation-for-new-tabs.md)）
- `feed_list_controller` — フィードペインの選択と移動（`s` / `a`）、すべて既読
- `entry_list_controller` — エントリ一覧の選択と移動（`j` / `k`）、選択したエントリを既読表示にする。`feed-list` outlet で選択中のフィードを参照し、`read` / `loaded` / `moved` イベントを出す
- `entry_detail_controller` — エントリ本文ペインのスクロール、新規タブで開く
- `badge_controller` — 未読数バッジの更新。`entry-list` の `read` / `loaded` を受けてフィード・フォルダのバッジを再計算する（サーバー再取得なし）

選択状態は各リストのコントローラーが要素 ID だけを持ち、インデックスは DOM から毎回導出する（[ADR 0002](adr/0002-derive-selection-cursor.md)）。`pin` と `entry_nav`（モバイルの前後ボタン）は `entry-list` outlet 経由で選択中のエントリを参照する。

その他（`help_dialog` / `hatena_bookmark` / `mobile_pane` / `dropdown` / `reload`）は単機能。
実装は `app/javascript/controllers/`、共有ヘルパーは `app/javascript/lib/`（`fetch_helper.js` の `fetchWithCsrf` / `openInBackground` など）。

## モデル構成

### Feed

`Feed` モデルは責務ごとに concern に分離されている。

```
app/models/
├── feed.rb                # コア（associations, validations, enums, scopes, ステータス管理）
└── feed/
    ├── fetching.rb        # HTTP fetch, リダイレクト追従, エンコーディング変換, RSS::Parser
    ├── ssrf_protection.rb # 名前解決とプライベートIP帯のブロック（Feed::SsrfError）
    ├── autodiscovery.rb   # HTML の <link rel="alternate"> から feed URL を検出
    ├── subscribable.rb    # 入力URLからの購読解決（Resolution: feed か candidates）
    ├── entry_importer.rb  # エントリインポート, フィードタイトル更新
    └── opml.rb            # OPML インポート/エクスポート
```

外部 URL を取りに行く経路（`fetching` / `autodiscovery`）は必ず `ssrf_protection` を通す。
`subscribable.resolve` は候補が複数あるとき `feed` を返さず `candidates` を返し、選択をユーザーに委ねる。

### Entry

```
app/models/
├── entry.rb             # コア（associations, validations, scopes, URL 正規化・content_url）
└── entry/
    └── rss_parser.rb    # RSS/Atom/RDF アイテムから属性ハッシュを生成
```

- **Entry** — `belongs_to :feed`, `duplicates_of` スコープ, `normalize_url`, `safe_url_for_link`（[ADR 0012](adr/0012-entry-url-sanitize.md)）
- 既読化・ピン留めはユーザー固有の状態なので `User` 側にある（`mark_entry_as_read!` / `pin_entry!` / `unpin_entry!`、状態は `UserEntryState`）
- **Entry::RssParser** — `attributes_from_rss_item` クラスメソッド（guid, title, url, author, body, published_at を抽出）

## 認証

Rails 8 の `bin/rails generate authentication` が生成した `Authentication` concern（`start_new_session_for` / `terminate_session`）の上に、パスワードレスのマジックリンク認証を載せている。詳細は [magic_link_auth.md](magic_link_auth.md)。
seed で 1 ユーザーのみ作成（`TSUBAME_EMAIL`）。

## 未実装

- 検索機能
