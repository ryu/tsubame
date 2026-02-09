# デプロイ手順

## 構成

- デプロイツール: Kamal 2
- デプロイ先: さくらのVPS
- コンテナレジストリ: (要設定)
- SSL: Let's Encrypt (kamal-proxy 経由)

## 初回セットアップ

### 1. VPS側の準備

```bash
# Docker インストール（さくらのVPS）
curl -fsSL https://get.docker.com | sh
```

### 2. config/deploy.yml の設定

- `servers.web` にVPSのIPアドレスを設定
- `proxy.ssl` と `proxy.host` を設定
- `registry` にコンテナレジストリを設定

### 3. シークレットの設定

```bash
# .kamal/secrets に以下を設定
KAMAL_REGISTRY_PASSWORD=<レジストリのパスワード>
RAILS_MASTER_KEY=<config/master.key の内容>
```

### 4. 初回デプロイ

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
bin/kamal logs       # ログ表示
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
