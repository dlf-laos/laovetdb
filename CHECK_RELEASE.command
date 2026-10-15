#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -d node_modules ]; then npm ci; fi
npm run preflight
npm run build:vercel
echo "Local checks passed. Online/Neon validation is separate."
