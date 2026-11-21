#!/bin/bash
set -euo pipefail

BACKUP_DIR=/home/ubuntu/backups/tsubame
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

CONTAINER=$(docker ps --filter "name=tsubame-web" --format "{{.Names}}" | head -1)

if [ -z "$CONTAINER" ]; then
  echo "$(date): ERROR - tsubame-web container not found" >&2
  exit 1
fi

docker exec "$CONTAINER" sqlite3 /storage/production.sqlite3 ".backup /tmp/tsubame_backup.sqlite3"

docker cp "$CONTAINER:/tmp/tsubame_backup.sqlite3" "$BACKUP_DIR/tsubame-$TIMESTAMP.sqlite3"

docker exec "$CONTAINER" rm -f /tmp/tsubame_backup.sqlite3

find "$BACKUP_DIR" -name "tsubame-*.sqlite3" -mtime +$RETENTION_DAYS -delete

echo "$(date): Backup completed - tsubame-$TIMESTAMP.sqlite3 ($(du -h "$BACKUP_DIR/tsubame-$TIMESTAMP.sqlite3" | cut -f1))"
