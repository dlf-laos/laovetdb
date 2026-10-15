# Development Pack 08 — GIS, Analytics, Integration, Notifications & Production Hardening

## Goal
Complete national-platform cross-cutting services and production-readiness gates.

## Database scope
Migrations `000600`–`000680`.

## Required services
- integration system/endpoint/mapping registry
- notification templates/messages/delivery adapters
- GIS layer registry/read models
- KPI/dashboard/metric snapshots
- scheduler/background jobs
- data-quality and controlled master merge workflows
- retention/archive configuration
- reporting/materialized/read-model support
- final performance indexes and integrity guardrails

## Rules
- External secrets stay in secret management; DB stores only references.
- Domain modules publish events rather than invoking SMS/email providers directly.
- GIS does not become a duplicate source of domain geometry.
- Dashboards use read models/views/materialized views/metric snapshots rather than uncontrolled joins at page load.
- Do not introduce a separate data warehouse in Phase 1 without explicit need.
- AI features remain advisory and human-reviewed for regulatory use.

## Production gates
Migration from zero, upgrade rehearsal, security/permission tests, E2E critical journeys, performance checks, backup/restore test, data-migration rehearsal, UAT and production-readiness review.

## Acceptance
No critical domain bypasses audit, authorization, outbox/integration boundaries or production observability. Deployment procedures are reproducible from source and environment configuration.
