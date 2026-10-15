# LVSP departmental release report — 5 October 2026

## Delivered source

`LVSP_RELEASE_20261004`, version `1.12.0-release-candidate.1`, is a separate local release candidate based on the latest inspected `LVSP_V17_ONLINE_AUTH` source. The Phase2 ZIP contains source even though its extracted folder is empty: 42 ZIP files match the current source, three source files differ, and one bundle README is absent. The current files preserve the newer export endpoints, store queries and forms; older ZIP source was not copied over them. Detailed comparisons are in `PHASE2_COMPARISON.json` and `PHASE2_*.diff`.

Existing veterinary registration, trade, reporting and other foundations are retained. The newly delivered departmental module supports monthly work plans/results and whole-LAK budget plans/actual expenditure, draft edits, submit/return/verify commands, separate reviewers, version conflict rejection, verified record locks, audit/outbox records and CSV export. It is internal tracking, not a new legal approval authority or an official accounting-system integration.

The provincial/monthly-reporting menu now opens the existing reporting screen. End-of-month default dates no longer shift back one day through UTC conversion in the Lao timezone. Existing platform feature toggles still apply.

## Security and operations changes

- Central role authorization now runs before manually implemented API handlers, including export endpoints and forced-password-change checks.
- Generic command payloads cannot override command-selected status/action fields.
- Production refuses local JSON storage; the Vercel entry requires database authentication, PostgreSQL, database URL and signing secret.
- Department PostgreSQL record, audit and outbox writes are transactional. Row locking/version checks reject concurrent stale edits. Database triggers prevent changes to verified departmental records and hard deletes.
- Tests use separate temporary JSON files. The local demonstration uses a separate `review-data.json`.
- Migration tooling supports both known ledger column formats and no longer explicitly disables certificate verification. Seed execution is transactional.
- Migration manifest, consolidated schema and schema inventory are synchronized. Existing migration files 000001–000920 were not changed.
- Node/pg dependencies and lockfile are synchronized; clean offline `npm ci --ignore-scripts` succeeded.
- Vercel adapter/build configuration, GitHub checks, local start/check scripts, branch upload script, deployment guide and departmental UAT checklist are supplied.

## Observed verification

| Check | Result |
| --- | --- |
| TypeScript build | Passed |
| Automated suite | 101 passed, 0 failed; includes executable HTTP tests and inherited source-contract tests |
| Package validation | Passed: 114 migrations, 12 seed files, 264 discovered tables, manifest/order/dependency/lexical checks |
| Fresh PostgreSQL 18.6 + PostGIS | All 114 migrations applied to an empty disposable local database |
| Migration rerun | Completed without reapplying tracked migrations |
| Reference seeds | Applied successfully to the disposable database |
| PostgreSQL login | Separate named test users authenticated successfully |
| PostgreSQL budget workflow | Create/edit/submit/verify passed; one concurrent edit committed and the stale edit was rejected |
| PostgreSQL audit/outbox | Four matching audit and outbox events verified for the tested budget record |
| Database record locks | Verified-record update and hard delete rejected by database triggers |
| Trade report view | 23 columns after 000920 in the disposable database |
| PostgreSQL monthly summary | Endpoint returned successfully on the disposable database |
| Browser | Login, monthly-work save/submit, budget save and displayed amounts verified with sample local data |
| Deployment build | `build:vercel` generated static web/field output |
| Command syntax | Shell launch/check/upload scripts and Node upload/adapter/database scripts checked |

The local Python environment lacks PyYAML, so the optional OpenAPI YAML parser check was skipped and is now explicitly reported by the validator. CI includes `requirements-validation.txt` to enable it. The inherited executable route-contract tests passed. No production performance/security certification is claimed.

## Existing Neon database

A read-only transaction inspected its migration ledger: **112 tracked migrations, no checksum mismatch**, with `000920_trade_permit_report_validity_columns.sql` and `000930_department_operations.sql` pending. No live schema or business data was modified. Existing applied migrations were preserved byte-for-byte in this release.

The disposable PostgreSQL tests are not a production Neon migration rehearsal, backup/restore test or complete real-data UAT. Live migration application, Vercel Preview, production push/deploy and official departmental acceptance remain pending.

## Local data incident

The initial legacy automated test was started in the original ONLINE_AUTH folder. Its test setup reset `apps/api/runtime/lvsp-data.json`; the prior contents were not captured and cannot be established. The legacy run was stopped. Existing older JSON backups were located but were not copied over the file because their equivalence to the previous contents is unknown. Neon was not affected. All later testing used isolated temporary data. Any recovery of earlier local-only records requires comparison with the user's backups.

## Remaining work requiring user/project information

1. Identify the full `laovetdb` GitHub URL, existing clone, production branch and Vercel project; inspect their current deployment before integration.
2. Verify backups and apply pending migrations on staging first; perform Preview deployment and representative real-data UAT.
3. Confirm the complete Veterinary Services Division task inventory and approved forms/SOPs. The package does not establish that every official departmental task is implemented.
4. Review legacy record ownership/geographic access and regulatory lifecycle endpoints. Central RBAC improvements do not constitute complete ABAC or domain-security coverage.
5. Configure needed attachment/object storage, official legal/reference values and external interfaces according to the department's approved scope.
6. Add other divisions only after the requested departmental/director approval.

The temporary PostgreSQL server was stopped after testing. The local review web server is available while its start session remains running; `START_REVIEW.command` can start it again.
