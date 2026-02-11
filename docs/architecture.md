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

- `keyboard_controller` — グローバルキーボードショートカット（フィード/エントリナビゲーション、アクション）
- `hatena_bookmark_controller` — はてなブックマーク数取得・表示（外部API連携）
- `mobile_pane_controller` — モバイル向けペイン切り替え

### JavaScript ライブラリ (`app/javascript/lib/`)

- `hatena_bookmark.js` — はてなブックマークページURL生成・オープン（共通ユーティリティ）

## 認証

Rails 8 の `bin/rails generate authentication` を使用。
seed で 1 ユーザーのみ作成。

## フェーズ計画

### Phase 1: MVP

1. プロジェクトセットアップ + Kamal デプロイ確認
2. 認証
3. OPML インポート
4. フィードクロール (Solid Queue)
5. 3ペインUI + キーボードショートカット
6. 既読管理
7. ピン

### Phase 2

- フィード発見 (autodiscovery)
- レート（★）によるフィード分類
- フォルダ管理
- OPML エクスポート
- 検索機能
