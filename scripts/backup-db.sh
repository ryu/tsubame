#!/bin/bash
#
# VPS上で実行するSQLiteバックアップスクリプト
# crontabに登録して定期実行する
#
# Setup:
#   chmod +x /home/ubuntu/bin/backup-db.sh
#   crontab -e
#   0 3 * * * /home/ubuntu/bin/backup-db.sh >> /home/ubuntu/backups/tsubame/backup.log 2>&1
#
set -euo pipefail

BACKUP_DIR=/home/ubuntu/backups/tsubame
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Find the running tsubame web container
CONTAINER=$(docker ps --filter "name=tsubame-web" --format "{{.Names}}" | head -1)

if [ -z "$CONTAINER" ]; then
  echo "$(date): ERROR - tsubame-web container not found" >&2
  exit 1
fi

# Create backup using SQLite's .backup command (safe with WAL mode)
docker exec "$CONTAINER" sqlite3 /rails/storage/production.sqlite3 ".backup /tmp/tsubame_backup.sqlite3"

# Copy from container to host
docker cp "$CONTAINER:/tmp/tsubame_backup.sqlite3" "$BACKUP_DIR/tsubame-$TIMESTAMP.sqlite3"

# Clean up temp file in container
docker exec "$CONTAINER" rm -f /tmp/tsubame_backup.sqlite3

# Remove old backups
find "$BACKUP_DIR" -name "tsubame-*.sqlite3" -mtime +$RETENTION_DAYS -delete

echo "$(date): Backup completed - tsubame-$TIMESTAMP.sqlite3 ($(du -h "$BACKUP_DIR/tsubame-$TIMESTAMP.sqlite3" | cut -f1))"
