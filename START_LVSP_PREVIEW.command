#!/bin/zsh
set -e
cd -- "$(dirname -- "$0")"
if [[ ! -f .env.preview.private ]]; then
  echo 'LVSP Preview configuration is missing. Please contact the system administrator.'
  exit 1
fi
npm run build
node scripts/start-local-preview.mjs
