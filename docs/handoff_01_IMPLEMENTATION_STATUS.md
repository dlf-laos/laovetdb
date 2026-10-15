# LVSP Implementation Status — What Is Complete vs What Still Must Be Built

## Complete and authoritative inputs

- Enterprise/business/data/application/workflow/security/API/UI/deployment architecture baseline.
- Development Pack 01–08 specifications.
- 90 ordered PostgreSQL migration files and consolidated schema.
- 12 baseline idempotent seed files and consolidated seed review file.
- Package validator, checksum-aware migration runner, seed runner and post-deploy sanity checks.
- Physical schema inventory and high-level ERD.
- Permission, workflow, API endpoint, frontend route, test and deployment manifests.
- OpenAPI 3.1 starter contract.
- Regulatory/reference-data CSV templates.

## Still to be implemented by Claude Code / developer

1. Actual TypeScript application source for API, web and field/mobile apps.
2. Domain/application services and repositories implementing the frozen database/domain rules.
3. REST endpoints and OpenAPI-backed request/response models.
4. Server-side RBAC/ABAC/scope enforcement and real identity-provider integration.
5. UI pages, task queues, 360-degree entity views, forms, Lao/English localization and offline field workflows.
6. Object-storage adapter and document upload/download implementation.
7. Background jobs, notifications, event publishing, integration adapters and retry/dead-letter behavior.
8. Unit, integration, E2E, permission, security, performance and offline-sync tests.
9. Runtime execution of all migrations/seeds against an empty PostgreSQL/Neon staging database.
10. Staging deployment, backup/restore rehearsal, UAT and production deployment.

## Must come from verified official/configuration sources rather than coding guesswork

- Lao legal fees and validity periods.
- Competent approval/signature authority and delegation rules.
- Statutory processing deadlines.
- Disease-specific regulatory restrictions and control rules.
- Laboratory legal/technical acceptance limits where governed by an official method/standard.
- Enforcement penalties.
- Final official certificate wording/templates/signature trust profile.
- Current authoritative Lao administrative geography and codes.
- Partner-system/NSW/Customs/e-Certificate interface credentials and agreements.

These items do **not** block software architecture or general implementation. They block only production-grade regulatory configuration for the affected service. Claude must use configuration placeholders and clearly mark them `PENDING_LEGAL_VERIFICATION`.
