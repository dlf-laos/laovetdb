#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "LVSP — Neon free/staging setup"
if ! command -v node >/dev/null 2>&1; then echo "Node.js 22+ is required. Install Node.js, then run this file again."; read -r; exit 1; fi
if [ -f .env.neon ] && grep -q '^DATABASE_URL=' .env.neon; then echo ".env.neon already has a DATABASE_URL. Nothing was overwritten."; echo "Run START_LVSP_NEON.command instead, or rename .env.neon if you want a new temporary database."; read -r; exit 0; fi
npm install
npx neon-new@latest --yes --ref lvsp-chatgpt --env .env.neon
SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
PASS=$(node -e "console.log(require('crypto').randomBytes(9).toString('base64url'))")
cat >> .env.neon <<ENV
LVSP_STORAGE=postgres
AUTH_MODE=local
LVSP_AUTH_SECRET=$SECRET
LVSP_BOOTSTRAP_ADMIN_USER=admin
LVSP_BOOTSTRAP_ADMIN_PASSWORD=$PASS
PORT=8787
ENV
node --env-file=.env.neon scripts/db-migrate.mjs
node --env-file=.env.neon scripts/db-seed.mjs
node --env-file=.env.neon scripts/db-check.mjs
CLAIM=$(grep '^PUBLIC_POSTGRES_CLAIM_URL=' .env.neon | cut -d= -f2- || true)
echo
printf 'FIRST LOGIN\nUsername: admin\nPassword: %s\n' "$PASS"
echo "Claim URL: $CLAIM"
echo "IMPORTANT: unclaimed Neon New databases expire after 72 hours. Open the Claim URL to keep the database in your Neon Free account."
echo "Next: double-click START_LVSP_NEON.command"
read -r
