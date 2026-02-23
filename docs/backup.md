# バックアップ

## 概要

SQLite3データベースのバックアップを2段階で行う。

1. **VPS内バックアップ**: cronで毎日`sqlite3 .backup`を実行（7日分保持）
2. **ローカル転送**: MacからrsyncでVPSのバックアップを取得（30日分保持）

バックアップ対象は `production.sqlite3`（メインDB）のみ。
cache/queue/cable の各DBは一時データのため対象外。

## スクリプト

| スクリプト | 実行場所 | 役割 |
|---|---|---|
| `scripts/backup-db.sh` | VPS | SQLiteバックアップ作成 |
| `scripts/fetch-backup.sh` | Mac | VPSからバックアップ取得 |

## VPS側セットアップ

```bash
# スクリプトを配置
ssh ubuntu@YOUR_SERVER_IP "mkdir -p ~/bin ~/backups/tsubame"
scp scripts/backup-db.sh ubuntu@YOUR_SERVER_IP:~/bin/
ssh ubuntu@YOUR_SERVER_IP "chmod +x ~/bin/backup-db.sh"

# 動作テスト
ssh ubuntu@YOUR_SERVER_IP ~/bin/backup-db.sh

# cronに登録（毎日3:00 JST）
ssh ubuntu@YOUR_SERVER_IP 'crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/bin/backup-db.sh >> /home/ubuntu/backups/tsubame/backup.log 2>&1"' | ssh ubuntu@YOUR_SERVER_IP crontab -
```

### 仕組み

1. `docker exec` で稼働中のコンテナ内の `sqlite3 .backup` を実行
2. `docker cp` でバックアップファイルをホストにコピー
3. 7日より古いバックアップを削除

`sqlite3 .backup` はWALモードでもロックなしで安全にコピーできる。

## Mac側セットアップ

```bash
# スクリプトを配置
mkdir -p ~/bin ~/backups/tsubame
cp scripts/fetch-backup.sh ~/bin/fetch-tsubame-backup.sh
chmod +x ~/bin/fetch-tsubame-backup.sh

# 動作テスト
~/bin/fetch-tsubame-backup.sh

# cronに登録（毎日8:00）
crontab -e
0 8 * * * $HOME/bin/fetch-tsubame-backup.sh >> $HOME/backups/tsubame/fetch.log 2>&1
```

## リストア

```bash
# バックアップファイルをVPSに転送
scp ~/backups/tsubame/tsubame-YYYYMMDD_HHMMSS.sqlite3 ubuntu@YOUR_SERVER_IP:/tmp/restore.sqlite3

# コンテナにコピーしてリストア
CONTAINER=$(ssh ubuntu@YOUR_SERVER_IP 'docker ps --filter "name=tsubame-web" --format "{{.Names}}" | head -1')
ssh ubuntu@YOUR_SERVER_IP "docker cp /tmp/restore.sqlite3 $CONTAINER:/rails/storage/production.sqlite3"

# アプリを再起動
bin/kamal app boot
```

## 確認方法

```bash
# VPS側のバックアップ一覧
ssh ubuntu@YOUR_SERVER_IP "ls -lh ~/backups/tsubame/"

# VPS側のログ確認
ssh ubuntu@YOUR_SERVER_IP "cat ~/backups/tsubame/backup.log"

# Mac側のバックアップ一覧
ls -lh ~/backups/tsubame/
```
