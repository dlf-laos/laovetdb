# CLAUDE.md — LVSP Authoritative Coding Instructions

You are implementing the Lao Veterinary Services Platform (LVSP). This repository contains an approved architecture/database baseline. Treat SQL migrations and frozen domain rules as authoritative. Do not redesign core relationships to fit a framework or ORM.

## Start
1. Read `README.md`.
2. Read `docs/13_CLAUDE_CODE_START_HERE.md` and `docs/10_CLAUDE_CODE_MASTER_INSTRUCTIONS.md`.
3. Read `claude-packs/00_MASTER_ORCHESTRATOR.md`.
4. Read `IMPLEMENTATION_STATE.json`.
5. Run `python scripts/validate_package.py`.
6. Implement Packs 01–08 sequentially with a test gate after each Pack.

## Frozen rules
- `master.party` -> Person/Company supertype.
- One permanent Facility UUID; many facility types/activities/components.
- One hierarchical administrative-unit model: Country → Province → District → Commune → Village.
- Case != Workflow Instance.
- Decision != Licence != Registration != Certificate.
- Product != Registration != Package.
- Establishment Approval != Operating Licence != GMP.
- Finding != Violation != CAPA != Enforcement.
- One shared Inspection Engine and one shared LIMS.
- Disease Case != Outbreak.
- Permit != Shipment != Border Inspection != Quarantine != Clearance != Health Certificate.
- Official regulatory/history data is immutable/versioned/auditable; no normal hard-delete path.
- Files belong in object storage; PostgreSQL stores metadata/object keys/checksums.
- Core relationships remain relational; JSONB is for configuration/snapshots/dynamic payloads only.
- External systems use APIs/adapters/events and never direct-write core tables.
- Regulatory state changes use application/domain commands; do not expose arbitrary raw status mutation.
- AI/risk scoring is advisory only, never competent legal/regulatory authority.

## Implementation protocol
For every Pack: plan → implement → lint/typecheck → unit/integration/E2E tests → migration-from-zero test → security/audit/outbox verification → fix failures → update `IMPLEMENTATION_STATE.json` → write `PACK_<NN>_COMPLETION_REPORT.md` → checkpoint/commit when possible → continue.

Do not stop for routine decisions. Use the package design. For unavailable external providers, build provider-neutral interfaces and test adapters. For unverified legal values, use versioned configuration marked `PENDING_LEGAL_VERIFICATION`; never invent values.

Before first dependency installation, replace broad/latest dependency declarations with explicit compatible versions and create a committed lockfile. The database is SQL-first: no ORM-generated redesign of migrations.

After Pack 08, create `FINAL_IMPLEMENTATION_REPORT.md` and run the complete release-hardening gate. Do not claim Neon/production validation unless you actually executed it on that environment.
