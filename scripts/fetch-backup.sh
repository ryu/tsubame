#!/bin/bash
#
# ローカルMacで実行するバックアップ取得スクリプト
# VPSからrsyncでバックアップファイルを取得する
#
# Setup:
#   chmod +x ~/bin/fetch-tsubame-backup.sh
#   # launchdまたはcrontabで定期実行（下記参照）
#
set -euo pipefail

REMOTE_USER=ubuntu
REMOTE_HOST=153.120.7.202
REMOTE_DIR=/home/ubuntu/backups/tsubame
LOCAL_DIR=~/backups/tsubame
RETENTION_DAYS=30

mkdir -p "$LOCAL_DIR"

# Sync backups from VPS
rsync -az "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/tsubame-*.sqlite3" "$LOCAL_DIR/"

# Remove old local backups
find "$LOCAL_DIR" -name "tsubame-*.sqlite3" -mtime +$RETENTION_DAYS -delete

COUNT=$(find "$LOCAL_DIR" -name "tsubame-*.sqlite3" | wc -l | tr -d ' ')
echo "$(date): Sync completed - $COUNT backups in $LOCAL_DIR"
