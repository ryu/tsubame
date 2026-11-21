#!/bin/bash
set -euo pipefail

REMOTE_USER=ubuntu
REMOTE_HOST=${TSUBAME_REMOTE_HOST:?Error: set TSUBAME_REMOTE_HOST}
REMOTE_DIR=/home/ubuntu/backups/tsubame
LOCAL_DIR=~/backups/tsubame
RETENTION_DAYS=30

mkdir -p "$LOCAL_DIR"

rsync -az "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/tsubame-*.sqlite3" "$LOCAL_DIR/"

find "$LOCAL_DIR" -name "tsubame-*.sqlite3" -mtime +$RETENTION_DAYS -delete

COUNT=$(find "$LOCAL_DIR" -name "tsubame-*.sqlite3" | wc -l | tr -d ' ')
echo "$(date): Sync completed - $COUNT backups in $LOCAL_DIR"
