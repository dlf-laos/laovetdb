# Deployment of the departmental release candidate

Local and disposable PostgreSQL validation is complete. GitHub push, Vercel Preview/Production, production migrations, backup restore and departmental UAT have not been executed.

## Repository and hosting

Confirm the full GitHub URL ending in `laovetdb`, repository owner, current production branch and Vercel project. The present source folder has no Git history. Do not initialize and force-push it over the existing repository.

`UPDATE_GITHUB.command` requires a separate, clean existing clone. It validates this release, copies the reviewed source into that clone, creates a new branch, commits and pushes that branch. It stops on errors, dirty working trees and an unexpected origin repository name. Existing tracked deployment files in the clone must be reviewed in the resulting diff; this script has not been tested against the actual repository because its location/URL is not known.

Connect that repository to the intended Vercel project, with the repository root as Root Directory. The supplied configuration uses:

- Node.js 24, `npm ci --include=dev`, `npm run build:vercel`.
- Static output in root `public/`; these are generated copies of `apps/web/public` and `apps/field/public`.
- A Node HTTP adapter in `api/index.js` for `/api/v1/*`, `/health`, `/ready`.
- Bundled compiled backend, route catalog, web/field assets, OpenAPI and VERSION.

This configuration follows [Vercel Node functions](https://vercel.com/docs/functions/runtimes/node-js), [configuration](https://vercel.com/docs/project-configuration/vercel-json), and [supported Node versions](https://vercel.com/docs/functions/runtimes/node-js/node-js-versions). A successful local build is not evidence of a successful Vercel deployment. Verify request paths, bundled files, database connectivity and authenticated workflows in Preview before merging.

Set Preview and Production environment variables separately:

| Variable | Setting |
| --- | --- |
| `NODE_ENV` | `production` |
| `AUTH_MODE` | `database` |
| `LVSP_STORAGE` | `postgres` |
| `DATABASE_URL` | Intended Neon pooled endpoint with verified TLS |
| `LVSP_AUTH_SECRET` | Unique random secret of at least 32 characters |
| `DB_POOL_MAX` | `3` initially; review under load |

Do not enter development login passwords or commit a real `.env` file. Use existing authorized accounts and Admin Center for staff provisioning. The inherited OIDC path is not implemented; the supplied Vercel adapter requires database authentication.

## Database update

The read-only check of the existing configured Neon database found 112 tracked migrations and no checksum mismatch. `000920` and new `000930` are untracked. No live records or schema objects were changed.

Before an update: confirm the intended database/branch, create and verify a backup, and test on a separate staging branch. Do not rerun all historical migrations or seeds on an existing production database. Missing ledger entries alone do not prove that a view/table is absent.

Create a local `.env.staging` containing the staging `DATABASE_URL_DIRECT`; never commit it. From the release root:

```bash
node --env-file=.env.staging scripts/check-db-readiness.mjs
node --env-file=.env.staging scripts/apply-reviewed-migration.mjs 000920_trade_permit_report_validity_columns.sql
node --env-file=.env.staging scripts/apply-reviewed-migration.mjs 000930_department_operations.sql
```

The readiness command is read-only and returns exit code 2 for pending/mismatched files. The reviewed apply command performs a persistent update of the selected database, one named migration at a time, inside a transaction. It detects both known migration-ledger formats and refuses a changed applied checksum. `000920` adds validity columns to the existing report view; `000930` adds two departmental tracking tables and locks. Neither command starts automatically during build, test, GitHub upload or Vercel deploy.

The full `db:migrate` / `db:seed` commands are for a new disposable database or a separately reviewed migration plan. Full fresh migrations and seed execution have been tested on a temporary PostgreSQL 18.6 database with PostGIS.

## Acceptance before production

Test real representative drug-registration, company, import/export, permit-printing and report cases with department staff. Confirm ownership/geographic scope of legacy endpoints; the inherited application has broad role-based read access, and this release is not a complete ABAC/security certification. Confirm official forms, legal rules, attachment storage, issuer authority and external interfaces before using them operationally.

Check `/health`, `/ready`, individual login, forced password change, staff/reviewer separation, monthly summary, CSV export, PWA update, logout and deployed print layouts. The new work/budget module requires a second authorized user for review; the single local demo admin cannot self-verify.

Merge only after Preview and UAT pass. A Git-connected Vercel project can deploy the production branch on merge. Keep the previous deployment available for application rollback; retain additive database changes and verified history. Use a database restore only under an agreed recovery plan.
