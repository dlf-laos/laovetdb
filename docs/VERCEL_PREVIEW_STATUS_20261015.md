# LVSP Vercel Preview — 15 October 2026

The existing TypeScript continuation source was deployed to the existing `lvsp-laos` Vercel project as a protected Preview. The production alias was inspected afterward and remains on the earlier legacy deployment.

- Preview: https://lvsp-laos-jh9wt7a06-veterinary-srvices-division.vercel.app
- Deployment: `dpl_5jaXsVirohCSCzFdLcf7ojxSRTES`, Vercel status READY.
- Source checkpoint: `18bb902`. An exact Git archive was uploaded manually through the authenticated project owner. The first deployment from the local repository was blocked because its backup commit author was not a Vercel team member. No author identity was forged or history rewritten.
- Database: new `lvsp_preview_20261015` in the existing Neon project, on the same branch/compute as `neondb`. This is database-level isolation, not a separate Neon branch or independent compute. No production records were copied.
- Preview database role has no CREATEDB/CREATEROLE privileges. The existing administrator was granted membership to create the database owned by this role.
- All 115 migrations and reference seeds completed in the new database. One temporary administrator requires password change at first login.
- Preview environment: DATABASE_URL, AUTH_MODE=database, LVSP_STORAGE=postgres, LVSP_AUTH_SECRET, LVSP_AI_PROVIDER=gemini, DB_POOL_MAX=3. Secrets were provided to the CLI through stdin.
- GEMINI_API_KEY was confirmed present in Production only. Its value was not read. Preview still needs its own Gemini key/model settings and private object storage before document upload/extraction can operate.
- Private `.env.preview.private` and `.env.preview-access.txt` files are ignored by Git and Vercel. Never commit or share their contents.

The source upload list was checked: no `.env` files or local runtime data were included. Vercel Authentication protects the Preview; the owner may need to log into Vercel before reaching LVSP login.

Public HTTP verification from this computer timed out during DNS resolution for `vercel.app`. READY confirms successful build/deployment, not complete browser or deployed API verification. The local source can be checked against the Preview database separately; this does not replace a live browser check.

Production remains deployment `dpl_AFUBEjTDyGiV2jwBWVribH6aKRDK` at https://lvsp-laos.vercel.app. No production migration or source promotion was performed. The full AI pilot and modernization work are not complete.

Local HTTP verification using the deployed source checkpoint and the real isolated Neon Preview database passed: `/health` HTTP 200; `/api/v1/auth/login` HTTP 200 with token issuance and `mustChangePassword=true`. Passwords/tokens were not displayed. No official registration was created by this check.

## Private Neon storage continuation

Verified the Preview URL hostname against Neon's endpoint metadata: `ep-sweet-rice-ay39njxg` belongs to project `tiny-night-31200401`, branch `br-noisy-mode-ayam5w11`, region `aws-us-east-2`. The initial automatic approval rejection for a suspected target mismatch was resolved with this direct evidence before provisioning.

Created the new private bucket `lvsp-preview-dossiers`. A named storage read/write credential is stored only in ignored local configuration and Vercel Preview Secrets. The credential is branch-scoped: it can access storage buckets on this branch and its descendants; it is not restricted to a single bucket. No existing buckets were present when provisioned.

The existing AWS SDK adapter now supports an explicitly selected `neon-s3` mode with a validated Neon branch HTTPS endpoint and path-style requests. AWS S3 keeps its AES256 request; Neon uses provider-managed storage and does not send AWS-specific encryption settings. No AWS encryption-equivalence claim is made. The adapter still sends conditional PUT headers, but Neon conditional-overwrite enforcement has not been independently verified; all uploads receive fresh random UUID object keys.

Real synthetic integration passed using the existing LVSP API locally with the Preview database and real Neon storage: upload HTTP 201, authenticated download HTTP 200, byte-for-byte equality, anonymous storage read HTTP 403. A clearly labeled synthetic draft/file remains in Preview for verification. No real dossier was uploaded and no AI call was made.

Storage settings were added to Preview only. GEMINI_API_KEY remains Production-only pending the user's explicit approval to broaden its target. Automatic approval review rejected the attempted target change because it would grant Preview access to a Production credential; that request was not executed. AI model selection and live Gemini verification remain pending.

## Latest storage-enabled Preview

Source checkpoint `14ea1f0`; 117 isolated regression tests passed. Vercel deployment `dpl_76Ge2h5fjdfY2KzRKnTtzsV3SC6B` is READY at https://lvsp-laos-m8cxiyube-veterinary-srvices-division.vercel.app. This supersedes the earlier Preview URL above. Production was not promoted. Google DNS-over-HTTPS resolves the Preview hostname; the computer's ordinary resolver timed out. End-to-end public HTTP verification remains pending.
