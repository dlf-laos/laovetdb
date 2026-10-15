#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "Install Node.js 24 first."; exit 1; }
if [ ! -d node_modules ]; then npm ci; fi
npm run build
export NODE_ENV=development AUTH_MODE=local LVSP_STORAGE=json PORT=8787
export LVSP_LOCAL_DATA_FILE="$PWD/apps/api/runtime/review-data.json"
export LVSP_AUTH_SECRET=lvsp-local-review-only-do-not-use-online
if [ ! -f "$LVSP_LOCAL_DATA_FILE" ]; then node scripts/seed_demo.mjs; fi
echo "Open http://localhost:8787 — admin / lvsp-demo-change-me"
echo "Local demonstration only. PostgreSQL-only features require a staging Neon database."
echo "Press Control+C to stop."
node apps/api/dist/server.js
