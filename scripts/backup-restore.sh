#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
korora_local_guard
mkdir -p "$KORORA_ROOT/.local/backups"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="$KORORA_ROOT/.local/backups/korora-$stamp.dump"
restore_db="korora_restore_$(date -u +%Y%m%d%H%M%S)"
korora_k exec postgres-0 -- sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_dump -h 127.0.0.1 -U postgres -d korora -n api --no-owner --no-acl -Fc' > "$backup_file.tmp"
mv "$backup_file.tmp" "$backup_file"
korora_k exec postgres-0 -- sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; createdb -h 127.0.0.1 -U postgres "$1"' sh "$restore_db"
korora_k exec -i postgres-0 -- sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_restore -h 127.0.0.1 -U postgres --no-owner --no-acl --exit-on-error -d "$1"' sh "$restore_db" < "$backup_file"
source_count="$(korora_k exec postgres-0 -- psql -U postgres -d korora -Atc 'SELECT count(*) FROM api.measurements')"
restore_count="$(korora_k exec postgres-0 -- psql -U postgres -d "$restore_db" -Atc 'SELECT count(*) FROM api.measurements')"
test "$source_count" = "$restore_count"
echo "백업: $backup_file"
echo "복구 DB: $restore_db (원본 DB를 덮어쓰지 않았습니다)"
echo "행 수 일치: $source_count"
