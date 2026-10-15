# Development Pack 01 — Platform Foundation

## Goal
Create the monorepo foundation and implement Master Data, IAM, Workflow, Documents, Audit and Outbox/Inbox foundations.

## Database scope
Apply/own migrations from `000001_extensions.sql` through `000080_integration_outbox_inbox.sql`.

## Required modules
- security / IAM
- master data / geography / organization / facility registry foundation
- workflow definition/runtime
- document metadata/templates
- technical audit
- integration outbox/inbox
- central numbering, legal/rule/service registries

## Mandatory behavior
- `master.party` is the supertype for `master.person` and `master.company`.
- Roles such as importer/manufacturer/exporter are Party Role assignments, never duplicate master tables.
- `master.admin_unit` is hierarchical; do not create province/district/commune/village tables.
- User identity is separate from Person master.
- Authorization foundations use RBAC + access scope; all checks are server-side.
- Files are metadata + object storage references, never DB blobs.
- Running workflows stay on their original workflow version.
- Transactional outbox/inbox exists from the beginning.

## Application deliverables
- TypeScript monorepo scaffold for web/API/field apps and shared packages.
- REST/OpenAPI foundation, standardized errors, request/correlation IDs.
- health/readiness endpoints.
- repository/service boundaries for Foundation modules.
- migration and seed commands.

## Acceptance
- Empty PostgreSQL/Neon-compatible database migrates successfully from zero.
- Baseline seeds load idempotently.
- Party subtype integrity is enforced.
- Commune (`ຕາແສງ`) hierarchy works.
- Facility supports multiple type assignments.
- RBAC/scope, Workflow versioning, Document metadata, Audit, Outbox and Inbox tests pass.
- No business tables exist in `public`.
