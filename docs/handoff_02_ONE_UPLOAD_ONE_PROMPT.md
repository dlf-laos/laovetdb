# One Upload + One Master Prompt (Recommended)

Give Claude Code the entire `READY_REPO/` folder and paste the following prompt once.

```text
You are the lead implementation agent for the Lao Veterinary Services Platform (LVSP).

Treat this repository as the authoritative approved implementation baseline. Start by reading, in order:
1. CLAUDE.md
2. README.md
3. docs/13_CLAUDE_CODE_START_HERE.md
4. docs/10_CLAUDE_CODE_MASTER_INSTRUCTIONS.md
5. claude-packs/00_MASTER_ORCHESTRATOR.md
6. docs/01_FINAL_MIGRATION_MANIFEST.md
7. docs/03_PERMISSION_MANIFEST.md
8. docs/04_WORKFLOW_SEED_MANIFEST.md
9. docs/05_API_ENDPOINT_MANIFEST.md
10. docs/08_TEST_MATRIX.md
11. IMPLEMENTATION_STATE.json

First run the package validator. Then implement the application sequentially from Pack 01 through Pack 08.

IMPORTANT EXECUTION RULE:
Do not attempt all modules as one uncontrolled coding pass. Execute one Pack at a time with a hard test/checkpoint gate. After a Pack passes, update IMPLEMENTATION_STATE.json, write a concise PACK_<NN>_COMPLETION_REPORT.md, create a source-control checkpoint/commit when Git is available, and continue automatically to the next Pack unless a genuine blocker exists.

Do not stop merely because an external provider or official legal value is unavailable. Implement provider-neutral adapters/configuration and mark the missing item PENDING_EXTERNAL_CONFIGURATION or PENDING_LEGAL_VERIFICATION. Stop only if proceeding would corrupt the frozen architecture, destroy data, require a secret/credential that cannot be substituted in development, or require a legal value that is impossible to model as configuration.

Frozen rules include:
- Party -> Person/Company supertype.
- One permanent Facility UUID with multiple types/activities.
- One hierarchical admin-unit model supporting Commune/ຕາແສງ.
- Case != Workflow; Decision != Licence != Registration != Certificate.
- Product != Registration != Package.
- Establishment Approval != Operating Licence != GMP.
- Finding != Violation != CAPA != Enforcement.
- One shared Inspection Engine and one shared LIMS.
- Disease Case != Outbreak.
- Permit != Shipment != Border Inspection != Quarantine != Clearance != Health Certificate.
- Official regulatory history is immutable/auditable.
- Files are stored in object storage, not as PostgreSQL blobs.
- External systems never write directly to core tables.
- Regulatory state changes use domain/application commands, not arbitrary status PATCH operations.
- AI is advisory only and never legal/regulatory authority.

Pack execution order:
01 Platform Foundation
02 Regulatory Core
03 Facility/Product/Feed
04 Inspection/LIMS
05 Animal Traceability
06 Animal Health
07 Trade/Fisheries
08 Platform Hardening

Before the first dependency install, replace any broad/latest dependency declarations with explicit compatible versions and create/commit the lockfile. Do not silently change the approved database architecture to suit an ORM. The SQL migrations are authoritative.

For every Pack:
A. Read its claude-packs file and mapped migrations.
B. Produce a short implementation plan.
C. Implement source code, DB access, domain/application services, APIs/UI required by the Pack, authorization, audit/outbox integration and tests.
D. Run lint, typecheck, unit/integration tests and relevant E2E tests.
E. Run migration-from-zero tests on an available PostgreSQL runtime. If target Neon credentials are not available, use a disposable development PostgreSQL runtime and record that the Neon runtime gate remains pending.
F. Fix failures before continuing.
G. Update IMPLEMENTATION_STATE.json and create PACK_<NN>_COMPLETION_REPORT.md.
H. Continue automatically to the next Pack.

After Pack 08, run the final release gate: migration-from-zero, migration upgrade rehearsal, seed idempotency, permission/security tests, critical E2E journeys, object-storage tests, outbox/inbox retry tests, background jobs, performance checks, backup/restore rehearsal, and deployment-readiness checklist.

At the very end create FINAL_IMPLEMENTATION_REPORT.md containing:
- what was implemented;
- migrations and seeds executed;
- API/UI/module inventory;
- test results;
- security/audit/outbox coverage;
- remaining PENDING_LEGAL_VERIFICATION items;
- remaining PENDING_EXTERNAL_CONFIGURATION items;
- runtime/deployment environments actually verified;
- architecture deviations (normally none);
- exact next steps for staging/UAT/production.

Begin now with preflight validation and Pack 01, then continue sequentially without asking for routine confirmations.
```

## Why this is safer than “build everything at once”

The user uploads only one repo and gives one command, but Claude internally uses Pack gates. A national regulatory platform has too many dependent transactions to safely generate as a single untested pass. Pack gates reduce schema drift, duplicate models and hidden authorization/state-machine errors while still minimizing user interaction.
