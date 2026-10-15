#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env.neon ]; then echo "Run SETUP_NEON_FREE.command first."; read -r; exit 1; fi
npm run build
node --env-file=.env.neon apps/api/dist/server.js
