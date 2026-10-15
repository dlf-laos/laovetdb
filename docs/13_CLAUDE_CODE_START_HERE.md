# START HERE — Claude Code / Coding Agent

This is the first file to give a coding agent.

## Read in this exact order

1. `README.md`
2. `docs/13_CLAUDE_CODE_START_HERE.md`
3. `docs/10_CLAUDE_CODE_MASTER_INSTRUCTIONS.md`
4. `claude-packs/00_MASTER_ORCHESTRATOR.md`
5. `docs/01_FINAL_MIGRATION_MANIFEST.md`
6. `docs/03_PERMISSION_MANIFEST.md`
7. `docs/04_WORKFLOW_SEED_MANIFEST.md`
8. `docs/05_API_ENDPOINT_MANIFEST.md`
9. `docs/08_TEST_MATRIX.md`
10. `claude-packs/01_PLATFORM_FOUNDATION.md`

Do **not** begin Pack 02 until Pack 01 is implemented and its tests pass.

## First command to the coding agent

```text
Implement LVSP Development Pack 01 only.

Treat the SQL migrations and architecture rules in this package as authoritative.
Do not redesign the frozen core model and do not invent Lao legal/regulatory values.

Before coding:
1. run `python scripts/validate_package.py`;
2. read Pack 01 and its migrations;
3. produce a short implementation plan mapped to the approved modules/migrations.

Then implement Pack 01, including database migrations, application/domain boundaries,
server-side authorization foundations, audit/outbox behavior, REST/OpenAPI foundation,
and automated tests.

Do not expose direct raw status mutation APIs.
Do not create duplicate Person/Company/Facility master models.
Do not place business tables in `public`.

At Pack 01 completion report:
- migration inventory and results;
- schema/module/API inventory;
- automated test results;
- security/audit/outbox coverage;
- unresolved regulatory configuration;
- architecture deviations (normally none).

Stop after Pack 01 for review.
```

## Pack sequence

`01 Platform Foundation` → `02 Regulatory Core` → `03 Facility/Product/Feed` → `04 Inspection/LIMS` → `05 Animal Traceability` → `06 Animal Health` → `07 Trade/Fisheries` → `08 Platform Hardening`.

## Important distinction

This package is a developer-ready implementation baseline. It deliberately leaves unverified legal values as configuration. A coding agent must never fill those gaps from guesswork.
