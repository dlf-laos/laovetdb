#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_MIGRATION_URL:?DATABASE_MIGRATION_URL must be set}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIG_DIR="$ROOT/database/migrations"

command -v psql >/dev/null 2>&1 || { echo "ERROR: psql is required" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum is required" >&2; exit 1; }

ledger_exists() {
  psql "$DATABASE_MIGRATION_URL" -X -qAt -v ON_ERROR_STOP=1 \
    -c "SELECT to_regclass('system.schema_migration') IS NOT NULL" | grep -qx 't'
}

checksum_of() { sha256sum "$1" | awk '{print $1}'; }

# Bootstrap the first three idempotent migrations if the migration ledger does not yet exist.
if ! ledger_exists; then
  f1="$MIG_DIR/000001_extensions.sql"
  f2="$MIG_DIR/000002_schemas.sql"
  f3="$MIG_DIR/000003_common_functions.sql"
  echo "Bootstrapping $(basename "$f1"), $(basename "$f2"), $(basename "$f3")"
  psql "$DATABASE_MIGRATION_URL" -X -v ON_ERROR_STOP=1 -1 -f "$f1" -f "$f2" -f "$f3" \
    -c "INSERT INTO system.schema_migration(migration_name,sha256_checksum) VALUES
        ('$(basename "$f1")','$(checksum_of "$f1")'),
        ('$(basename "$f2")','$(checksum_of "$f2")'),
        ('$(basename "$f3")','$(checksum_of "$f3")')
        ON CONFLICT (migration_name) DO NOTHING;"
fi

for f in "$MIG_DIR"/*.sql; do
  name="$(basename "$f")"
  checksum="$(checksum_of "$f")"
  row="$(psql "$DATABASE_MIGRATION_URL" -X -qAt -v ON_ERROR_STOP=1 \
      -v mname="$name" \
      -c "SELECT sha256_checksum FROM system.schema_migration WHERE migration_name=:'mname';")"
  if [[ -n "$row" ]]; then
    if [[ "$row" != "$checksum" ]]; then
      echo "ERROR: applied migration checksum mismatch: $name" >&2
      echo "  database: $row" >&2
      echo "  file:     $checksum" >&2
      exit 1
    fi
    echo "Skipping $name (already applied)"
    continue
  fi
  echo "Applying $name"
  psql "$DATABASE_MIGRATION_URL" -X -v ON_ERROR_STOP=1 -1 -f "$f" \
    -v mname="$name" -v msum="$checksum" \
    -c "INSERT INTO system.schema_migration(migration_name,sha256_checksum) VALUES (:'mname', :'msum');"
done

echo "All migrations are applied and checksum-verified."
