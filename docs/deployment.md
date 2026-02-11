# デプロイ手順

## 構成

- デプロイツール: Kamal 2
- デプロイ先: さくらのVPS (153.120.7.202)
- コンテナレジストリ: GitHub Container Registry (ghcr.io)
- SSL: Let's Encrypt (kamal-proxy 経由)
- ホスト: tsubame.ryu-yamamoto.org

## 初回セットアップ

### 1. VPS側の準備

```bash
# Docker インストール（さくらのVPS）
curl -fsSL https://get.docker.com | sh
```

### 2. シークレットの設定

`.kamal/secrets` に以下を設定:

```
KAMAL_REGISTRY_PASSWORD=<GitHub Personal Access Token (write:packages)>
RAILS_MASTER_KEY=<config/master.key の内容>
```

### 3. 初回デプロイ

```bash
bin/kamal setup
```

## 通常デプロイ

```bash
bin/kamal deploy
```

## 便利コマンド

```bash
bin/kamal console    # Rails コンソール
bin/kamal shell      # bash
bin/kamal logs       # ログ表示（-f でフォロー）
bin/kamal dbc        # DB コンソール
```

## データの永続化

SQLite3 のデータベースファイルと Active Storage ファイルは
Docker ボリューム `tsubame_storage` に永続化される。

```yaml
volumes:
  - "tsubame_storage:/rails/storage"
```

## ロールバック

```bash
bin/kamal rollback <version>
```
