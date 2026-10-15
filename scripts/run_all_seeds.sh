#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_MIGRATION_URL:?DATABASE_MIGRATION_URL must be set}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v psql >/dev/null 2>&1 || { echo "ERROR: psql is required" >&2; exit 1; }
for f in "$ROOT"/database/seeds/*.sql; do
  echo "Loading $(basename "$f")"
  # Seed files are written to be idempotent. Each file is atomic.
  psql "$DATABASE_MIGRATION_URL" -X -v ON_ERROR_STOP=1 -1 -f "$f"
done
echo "All baseline seeds loaded."
