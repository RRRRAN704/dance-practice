#!/usr/bin/env bash
# Daily Postgres backup, run by cron on the EC2 host (see dance-backup.cron).
#
#   pg_dump (custom format, compressed)  ->  backups/<timestamp>.dump   kept here for 7 days
#                                         ->  s3://$BACKUP_BUCKET/daily/  expired by an S3 lifecycle rule
#
# The instance role may only put and read objects in the bucket, never delete them, and the bucket is
# versioned, so a compromised server can't wipe or overwrite old backups.
set -euo pipefail

cd "$(dirname "$0")"
BUCKET="${BACKUP_BUCKET:-dance-practice-backups-696530391359}"
KEEP_LOCAL_DAYS=7
COMPOSE=(docker compose -f docker-compose.prod.yml)

mkdir -p backups
chmod 700 backups
stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
file="backups/dance_practice-$stamp.dump"

echo "[$(date -u +%FT%TZ)] backup start"

# Write to a temp name first, so a half-written dump is never mistaken for a good one.
"${COMPOSE[@]}" exec -T postgres pg_dump -U dance -d dance_practice -Fc > "$file.partial"

# A dump that pg_restore can't read is worthless: check its table of contents before keeping it.
"${COMPOSE[@]}" exec -T postgres pg_restore --list < "$file.partial" > /dev/null
mv "$file.partial" "$file"
chmod 600 "$file"
echo "dump ok: $file ($(du -h "$file" | cut -f1))"

aws s3 cp --only-show-errors "$file" "s3://$BUCKET/daily/$(basename "$file")"
echo "uploaded to s3://$BUCKET/daily/"

find backups -name '*.dump' -mtime +"$((KEEP_LOCAL_DAYS - 1))" -delete
find backups -name '*.partial' -delete
echo "[$(date -u +%FT%TZ)] backup done"
