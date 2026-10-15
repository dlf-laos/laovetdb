# Execution Steps and Gates

## Step 0 — Preflight and repository normalization
Claude reads the authoritative docs, runs `python scripts/validate_package.py`, removes no approved migration, pins dependency versions, generates the lockfile, configures lint/typecheck/test commands, and records the runtime it can use for PostgreSQL tests.
**Gate:** package validation passes; repository installs/build tooling initializes; no architecture deviation.

## Step 1 — Packs 01–02: Foundation + Regulatory Core
Build monorepo runtime, API foundation, master data, IAM/scopes, workflow, documents, audit/outbox, universal case/application, decisions, registration/licensing/certificates.
**Gate:** empty DB migration + seeds succeed; authz/state transition tests pass; application→decision→licence/registration/certificate critical journey passes.

## Step 2 — Packs 03–04: Facilities/Products/Feed + Inspection/LIMS
Build facility/factory/GMP/product/feed lifecycles, then shared inspection/compliance/enforcement and LIMS.
**Gate:** Establishment Approval remains separate from Operating Licence/GMP; Product remains separate from Registration/Package; checklist versioning, CAPA, chain of custody and immutable approved lab-result tests pass.

## Step 3 — Packs 05–06: Traceability + Animal Health
Build farm/animal/group identity, movement and event history; surveillance, disease cases, outbreaks, zones/restrictions, vaccination, emergency/AMR.
**Gate:** traceability history is reconstructable; movement checks disease restrictions through services; suspected case→sample→LIMS→authorized outbreak/control flow passes.

## Step 4 — Pack 07: Trade/Border/e-Certificate/Fisheries
Build operator/permit/shipment/declaration/border inspection/quarantine/clearance/certificate and aquaculture records using shared engines.
**Gate:** complete shipment trace passes without collapsing Permit/Shipment/Inspection/Quarantine/Clearance/Certificate identities; e-Certificate adapter works with a mock partner when real endpoint is unavailable.

## Step 5 — Pack 08 + Release Hardening
Build notifications, scheduler, integration registry, GIS read models, KPI/dashboard framework, data quality, retention/archive, observability, performance indexes and deployment pipelines.
**Gate:** final security/E2E/performance/backup-restore/deployment readiness passes on staging-compatible infrastructure.

## Step 6 — Official configuration + UAT + production
Import verified Lao geography and legal/regulatory values; configure real identity, object storage, notifications, e-signature and government integrations as available; conduct UAT and production-readiness sign-off.
**Gate:** competent project owners approve configuration, UAT and production release. This is the only stage that cannot be completed solely from the software package because it depends on official data, credentials and institutional approval.
