# LVSP current state and AI pilot plan — 15 October 2026

## A. What exists now

The current workspace contains two substantially different applications:

- `LAOVETDB_PAGES_20261005`: the single-file legacy registry packaged for the `lvsp-laos` Vercel Drop deployment. Its deployment receipt identifies Ready status from the earlier dashboard inspection. The package has no server API or PostgreSQL connection; registry persistence is browser storage, with optional separately configured legacy integrations. The new monthly work/budget addition also uses browser storage.
- `LVSP_RELEASE_20261004`: the existing TypeScript LVSP monorepo, version `1.12.0-rc.1`, with API, web/field clients, shared packages, PostgreSQL adapter, authentication, company master, trade, registration case/review logic, audit/outbox infrastructure, and 114 migration files. This is the candidate development continuation base, not a replacement demo and not proven to be the current Vercel source.
- `LVSP_V17_ONLINE_AUTH`: the predecessor working tree, with 113 migrations and a configured Neon environment. API/server/frontend differ from the release candidate; migration 000910 is identical. Actual environment values were not printed or copied into the release. Other REPO2, RESET, failed-version and patch directories remain historical candidates, not deployment inputs.
- The named `LVSP_V17_PHASE2_SOURCE_20260909_065802` directory currently exposes no regular source files through recursive enumeration. Its name alone cannot establish source authority.

There is no `.git` checkout in the release candidate. A source archive was made before these additions at `/Users/workaroud/Desktop/LVSP_MIGRATION_BACKUPS/LVSP_RELEASE_BEFORE_AI_20261015.tar.gz`, SHA-256 `f5d503b6128b09b46cd2ef2157e0e8f4e5cb1ee55700ec47bcc42469f4022085`. It excludes environment files, dependencies, compiled dist/public output and named runtime data files. This is a source recovery point, not a database backup or proof of working Git history.

## B. What is working / verified

The configured local Neon connection was inspected read-only. Its migration ledger has 112 entries and no checksum mismatches against the candidate. Untracked local migrations: 000920 and 000930. No migration or seed was applied.

Read-only schema/count inspection found:

| Existing table | Rows |
|---|---:|
| master.company | 32 |
| product.product | 26 |
| product.product_regulatory_profile | 26 |
| product.product_common_composition | 0 |
| registration.veterinary_drug_application | 0 |
| document.document | 0 |
| document.file | 0 |

The detailed column inventory is in `AI_SCHEMA_AUDIT_20261015.json`. Existing registration code joins shared company/facility masters, document metadata, reviews, state transitions and certificates. These are inspected capabilities; zero case/document rows mean the new operational workflow is not demonstrated by existing live cases.

Four direct tests of the new extraction contract pass. The full TypeScript application build also passed. The isolated full regression suite passes: 105 tests, 0 failures. One pre-existing PWA assertion was updated to accept the existing release cache naming format; application behavior was unchanged.

## C. Old, duplicated or problematic

- Deployed legacy registry and the monorepo are different source lines. Do not automatically upload the monorepo over the legacy deployment or treat browser records as migrated database records.
- The monorepo still contains active standalone provincial-reporting UI, API handlers and runtime mappings. This conflicts with the master instruction. Do not recreate it; plan retirement of its interface/routes without deleting historical records or province/location master data.
- Registration currently expects an existing regulatory profile before creating a case. Upload-first intake therefore needs a preliminary draft linked to documents before the official profile/case is confirmed.
- Document metadata tables and routes exist, but this inspection did not establish a secure binary-upload/private-object-storage pipeline or an AI provider integration.
- Source migration 000910 contains size modes, antimicrobial fields, shared composition and herbal category. Inspection has not yet verified end-to-end combined-mode certificate behavior. Treat one certificate/no A-B suffixes as a required regression test, not a completed feature.
- Configuration examples differ between source generations. Vercel project environment values and their relationship to the locally configured Neon database remain unverified.

## D. Keep

Keep the existing company/party/facility and product/package/profile model; PostgreSQL migrations; authentication and server-side authorization; operational drug review/state commands; audit/outbox design; trade and annual-plan concepts; bilingual UI foundations; province/district/location reference data. Keep original documents as evidence linked to structured records.

## E. Change

Continue inside the existing monorepo. Establish a reviewed Git baseline and reconcile deployment provenance before publishing. Retire the removed provincial workspace separately from general department work/budget functions. Introduce upload-first intake and a side-by-side evidence/field/checklist review screen rather than another data-entry wizard. Do not silently auto-create or merge master data.

## F. Database and deployment risks

- The local Neon connection is verified; the active Vercel database is not. Do not assume they are the same.
- 000920/000930 lack ledger entries; absence of an entry is not proof that all corresponding objects are absent. Inspect dependencies before applying.
- There is no fresh full database backup from this audit. Obtain a recoverable database backup/branch before significant production migrations.
- Production currently failed a read-only HTTP check with a DNS resolution timeout from this machine. That does not establish an application-code failure. No rollback, DNS change, database write or deployment was performed.
- Existing authentication code and authorization checks were located, but this audit is not a completed security certification. Uploaded dossiers require private storage and authorized download paths before pilot use.

## G. Exact implementation sequence

1. Reconcile the Vercel source/deployment/environment with this candidate; establish Git history, separate staging configuration and a database recovery point.
2. Add an intake draft linked to existing document metadata, with case-scoped private upload/download authorization, MIME/content and size limits, checksums, retention and parser isolation. Prefer direct private-object uploads over large serverless request bodies. Do not persist dossiers in public web assets or ephemeral Vercel files.
3. Add a server-only, replaceable extraction provider and processing jobs. Read content to classify documents; do not classify by filename alone. Validate structured output and maintain model/provider/schema/version/error provenance. Never send production documents to an unconfigured provider.
4. Map validated extraction into draft fields using the existing product/profile/company/package model. Search existing masters; present possible matches without auto-merging. Preserve field evidence, page/location, confidence, corrections, reviewer and timestamps. The new contract is an initial boundary, not the complete regulatory field schema.
5. Build the review workspace in the existing registration UI: source viewer on the left, fields/checklist on the right. Missing/conflicting values stay flagged. Generate missing/corrected-document requests from reviewed checklist items. Completeness rules must come from the registration requirement configuration, not inferred legal requirements.
6. Confirm through an authenticated, authorized PostgreSQL transaction with draft version checks, duplicate prevention, field/correction audit, document linkage and outbox event. Confirmation creates structured draft/domain records; official approval/certificate issuance continues through existing authorized regulatory commands.
7. Test unauthorized document access, malicious/invalid uploads, invalid model JSON, missing evidence, cross-case source references, prompt-injection content, master matching, concurrent confirmation and idempotency. Add combined/single/multi packaging and certificate regression tests before deployment.
8. Pilot representative Lao/English/Thai dossiers in staging with staff review, then publish the existing application through the verified Vercel source pipeline. No provincial reporting module is introduced.

## Safe implementation started

`apps/api/src/core/document-intake.ts` defines a provider interface, allowed initial fields, strict structured-output validation, authorized-document evidence boundaries, missing-value normalization and review flags. It has no network call, API key, endpoint, persistence, approval or official-record write. Four tests in `apps/api/test/document-intake.test.mjs` pass against the source using Node 24. This is the first backend foundation; upload/classification/OCR/provider execution/review UI/transactional confirmation are not yet implemented.

`scripts/audit-ai-readiness.mjs` provides repeatable read-only schema/count inspection without printing credentials or document content.

## Validation completion

- Full TypeScript build: passed.
- Isolated regression suite: 105 passed, 0 failed.
- Production changes: none.
- Live schema inspection: read-only; no document contents or credentials recorded.
- Preserved profile columns verified in the live schema: size_mode, am_class, am_importance, am_growth_promoter.
