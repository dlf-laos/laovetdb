# Final Build Handoff

## Completed in this package

- Business, data, application, workflow, security, API/UI and deployment architecture baselines.
- Development Packs 01–08 implementation specifications.
- A concrete SQL migration file for every item in the Wave 1–8 migration manifest.
- Consolidated schema and generated schema inventory.
- Core seed SQL and permission/workflow catalogs.
- OpenAPI starter contract.
- TypeScript monorepo scaffold and environment template.
- Pack 01–08 coding-agent instruction files and a first-run handoff prompt.
- Checksum-aware migration execution, atomic seed execution and expanded package integrity validation.

## Intentionally left as verified configuration, not fabricated data

The package does **not** invent Lao legal fees, licence/registration validity periods, approval authorities, statutory deadlines, exact disease-specific movement restrictions, laboratory acceptance limits, enforcement penalties, official certificate wording, or the current full Lao administrative geography. These values must come from officially verified legal/reference sources and are modeled as versioned/configurable data.

## Recommended implementation sequence

1. Create an empty staging Neon/PostgreSQL database.
2. Set `DATABASE_MIGRATION_URL` with migration privileges.
3. Run `python scripts/validate_package.py`.
4. Run `scripts/run_all_migrations.sh` (applied migration checksums are recorded in `system.schema_migration`).
5. Run `scripts/run_all_seeds.sh`.
6. Import approved reference data (Lao geography, countries, species/breeds, legal instruments, regulatory rules, forms/templates).
7. Implement Pack 01 application services and automated tests.
8. Continue Packs 02–08 in order; do not redesign the frozen core relationships.
9. Run security, E2E, performance, migration-upgrade, backup/restore and UAT gates before production.

## What “complete” means here

This package completes the **developer-ready design and database build specification**. It does not claim that the SQL has already been executed in the user's Neon account or that a production application has been deployed. Actual deployment requires the target credentials/infrastructure and official regulatory configuration.


## Coding-agent handoff

Give the coding agent `docs/13_CLAUDE_CODE_START_HERE.md` first. The agent must implement Pack 01 before proceeding sequentially through Pack 08.
