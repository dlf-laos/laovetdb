#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_MIGRATION_URL:?DATABASE_MIGRATION_URL must be set}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v psql >/dev/null 2>&1 || { echo "ERROR: psql is required" >&2; exit 1; }
psql "$DATABASE_MIGRATION_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/database/post_deploy_sanity_checks.sql"
