#!/usr/bin/env bash
# Restore drill: prove a backup can actually be restored, without touching production.
#
#   ./restore-drill.sh            restore the newest backup in S3
#   ./restore-drill.sh FILE.dump  restore a local dump file
#
# It starts a throwaway Postgres container, restores the dump into it, then compares the row count of
# every table with production. Rows written after the backup was taken show up as small differences.
set -euo pipefail

cd "$(dirname "$0")"
BUCKET="${BACKUP_BUCKET:-dance-practice-backups-696530391359}"
COMPOSE=(docker compose -f docker-compose.prod.yml)
DRILL=pg-restore-drill
work=$(mktemp -d)

cleanup() {
  docker rm -f "$DRILL" > /dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

if [ $# -ge 1 ]; then
  dump="$1"
else
  key=$(aws s3 ls "s3://$BUCKET/daily/" | sort | tail -n 1 | awk '{print $4}')
  [ -n "$key" ] || { echo "no backups found in s3://$BUCKET/daily/"; exit 1; }
  dump="$work/$key"
  aws s3 cp --only-show-errors "s3://$BUCKET/daily/$key" "$dump"
  echo "downloaded s3://$BUCKET/daily/$key"
fi

# Same image, user and database name as production, so the dump restores exactly as it would for real.
docker run -d --name "$DRILL" -e POSTGRES_USER=dance -e POSTGRES_DB=dance_practice \
  -e POSTGRES_PASSWORD=drill postgres:16-alpine > /dev/null
until docker exec "$DRILL" pg_isready -U dance -d dance_practice -q; do sleep 1; done
sleep 2   # the image restarts Postgres once after its first-run setup

start=$(date +%s)
docker exec -i "$DRILL" pg_restore -U dance -d dance_practice --exit-on-error --no-owner < "$dump"
echo "restored $(basename "$dump") in $(( $(date +%s) - start ))s"

# Exact row count of every table in the public schema, as "table count" lines.
row_counts() {
  local sql
  sql=$("$@" psql -U dance -d dance_practice -tAc "
    select string_agg(format('select %L, count(*) from public.%I', table_name, table_name), ' union all ')
    from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'")
  "$@" psql -U dance -d dance_practice -tA -F ' ' -c "$sql" | LC_ALL=C sort
}

row_counts "${COMPOSE[@]}" exec -T postgres > "$work/prod.txt"
row_counts docker exec -i "$DRILL" > "$work/restored.txt"

printf '\n%-28s %10s %10s\n' TABLE PRODUCTION RESTORED
LC_ALL=C join -a 1 -a 2 -e - -o 0,1.2,2.2 "$work/prod.txt" "$work/restored.txt" |
  while read -r table prod restored; do printf '%-28s %10s %10s\n' "$table" "$prod" "$restored"; done

if diff -q "$work/prod.txt" "$work/restored.txt" > /dev/null; then
  echo -e "\nDRILL PASSED: every table matches production."
else
  echo -e "\nDRILL FINISHED WITH DIFFERENCES: check whether they are rows written after the backup."
  exit 1
fi
