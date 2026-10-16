# Local Preview sign-in repair — 16 October 2026

The existing database and Preview account were healthy: ACTIVE, zero failed logins, not locked, first password change required. Direct PostgreSQL connections from this machine timed out even after DNS resolution. The official Neon WebSocket Client connected to the same isolated Preview database with TLS intact.

The existing PostgresStore now supports explicit LVSP_PG_TRANSPORT=neon-ws; TCP remains the default. WebSocket mode rejects non-Neon hostnames. Pool acquisition has a 10-second timeout and idle pool errors are handled. The local Preview launcher explicitly selects neon-ws. No new account, password reset, database copy, or production data migration was performed.

Verified local /ready returned 200 with database lvsp_preview_20261015, and POST /api/v1/auth/login returned 200 using the existing bootstrap credentials privately. Browser sign-in reached the mandatory Change password screen. The user must enter and submit their new password themselves. Local address: http://127.0.0.1:8793/?module=admin_center . This does not verify the public Vercel deployment or live Gemini requests.

Changed API dependency: official @neondatabase/serverless pinned in apps/api/package.json and root lockfile. Source changes saved in the existing project. Temporary active runtime: /private/tmp/lvsp-runtime-check; launcher /private/tmp/lvsp-start-local-preview.mjs . These changes have not yet been published to GitHub/Vercel.
