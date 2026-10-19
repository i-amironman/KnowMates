#!/bin/sh
set -eu
stamp=$(date +%F)
out="/var/backups/knowmates-$stamp.sql.gz"
mkdir -p /var/backups
docker compose -f /opt/knowmates/deploy/docker-compose.prod.yml exec -T postgres \
  pg_dump -U knowmates knowmates | gzip > "$out"
find /var/backups -name 'knowmates-*.sql.gz' -mtime +7 -delete
if [ -n "${RCLONE_REMOTE:-}" ]; then
  rclone copy "$out" "$RCLONE_REMOTE"
fi
