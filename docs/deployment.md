# デプロイ手順

## 構成

- デプロイツール: Kamal 2
- デプロイ先: お使いのVPS
- コンテナレジストリ: GitHub Container Registry (ghcr.io)
- SSL: Let's Encrypt (kamal-proxy 経由)

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
  - "tsubame_storage:/storage"
```

コンテナは UID 1000 (`rails`) で動くため、Dockerfile 側で `/storage` を
`rails` 所有で作っておく必要がある。これを怠ると新規ボリュームが root 所有で
初期化され、SQLite が `unable to open database file` で起動に失敗する。

## ロールバック

```bash
bin/kamal rollback <version>
```

## SSH の設定

Kamal は `ubuntu` ユーザー・公開鍵認証で接続する（`config/deploy.yml` の `ssh.user`）。
サーバー側は `/etc/ssh/sshd_config.d/99-hardening.conf` でパスワード認証を無効化している。

```
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
```

drop-in として置いているため、OS 側の `sshd_config` が更新されても設定は残る。

秘密鍵を失うと復旧手段が VNC コンソール（シングルユーザモード）経由のみになるため、
`config/master.key` と同じ場所にバックアップしておくこと。

設定を変更する場合は、既存の SSH セッションを開いたまま検証する。

```bash
sudo sshd -t && sudo systemctl reload ssh   # 構文チェックしてから reload
ssh ubuntu@<host> 'echo OK'                 # 別セッションで疎通確認
```

`reload` は既存接続を切らないので、失敗しても元のセッションから戻せる。
