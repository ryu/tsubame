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

### Stimulus コントローラー構成

- `keyboard_controller` — グローバルキーボードショートカット。keydown ルーターとして各コマンドをイベントでディスパッチ
- `selection_controller` — キーボードコマンドの実行先。フィード/エントリナビゲーション、スクロール、既読管理、はてブ操作等を担う中央ハブ
- `pin_controller` — ピン追加/解除・ピン済みエントリを開く（selection outlet 経由）
- `help_dialog_controller` — ヘルプダイアログの開閉
- `hatena_bookmark_controller` — はてなブックマーク数取得・表示（外部API連携、バッチ取得）
- `mobile_pane_controller` — モバイル向けペイン切り替え（feeds / entries / detail）

### JavaScript ライブラリ (`app/javascript/lib/`)

- `fetch_helper.js` — `fetchWithCsrf`（CSRF トークン自動付与）、`openInBackground`（背面タブで開く）
- `hatena_bookmark.js` — はてなブックマークページURL生成・オープン

## モデル構成

### Feed

`Feed` モデルは責務ごとに concern に分離されている。

```
app/models/
├── feed.rb                # コア（associations, validations, enums, scopes, ステータス管理）
└── feed/
    ├── fetching.rb        # HTTP fetch, SSRF 防御, エンコーディング変換
    ├── autodiscovery.rb   # HTML から feed URL を自動検出
    ├── entry_importer.rb  # エントリインポート, フィードタイトル更新
    └── opml.rb            # OPML インポート/エクスポート
```

- **Feed** — `has_many :entries`, enum, バリデーション, `record_successful_fetch!` / `record_fetch_error!`
- **Feed::Fetching** — `fetch`, HTTP リダイレクト追従, SSRF 防御, エンコーディング変換, `RSS::Parser.parse` によるフィードオブジェクト生成
- **Feed::Autodiscovery** — `discover_from(url)`, HTML `<link rel="alternate">` 解析, フォールバックパス推測
- **Feed::EntryImporter** — `import_entries`, `update_feed_title`
- **Feed::Opml** — `import_from_opml`, `to_opml`

### Entry

```
app/models/
├── entry.rb             # コア（associations, validations, scopes, mark_as_read!, toggle_pin!）
└── entry/
    └── rss_parser.rb    # RSS/Atom/RDF アイテムから属性ハッシュを生成
```

- **Entry** — `belongs_to :feed`, `mark_as_read!`, `toggle_pin!`, `safe_url_for_link`
- **Entry::RssParser** — `attributes_from_rss_item` クラスメソッド（guid, title, url, author, body, published_at を抽出）

## 認証

Rails 8 の `bin/rails generate authentication` を使用。
seed で 1 ユーザーのみ作成。

## 実装状況

### 完了済み

- プロジェクトセットアップ + Kamal デプロイ
- 認証（Rails 8 authentication generator）+ パスワード変更
- OPML インポート / エクスポート
- フィードクロール (Solid Queue)
- フィード発見 (autodiscovery)
- 3ペインUI + キーボードショートカット
- 既読管理
- ピン
- はてなブックマーク連携
- モバイル対応
- エントリ自動削除（90日経過 & 既読 & 非ピン）
- バックアップ（VPS + ローカル転送）
- レート（★）によるフィード分類（0〜5、フィルタリング対応）

### 未実装

- フォルダ管理
- 検索機能
