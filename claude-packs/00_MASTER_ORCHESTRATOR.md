# LVSP Claude Code Master Orchestrator

Implement the Lao Veterinary Services Platform (LVSP) from this package. The architecture in `README.md`, `docs/10_CLAUDE_CODE_MASTER_INSTRUCTIONS.md`, and the SQL migrations is authoritative. Do not redesign frozen core relationships.

## Execution protocol

1. Read `docs/13_CLAUDE_CODE_START_HERE.md` first.
2. Validate the package with `python scripts/validate_package.py`.
3. Work through Packs 01–08 strictly in order.
4. Before each Pack, read its file in `claude-packs/` and the migrations assigned to that Pack.
5. Do not invent Lao regulatory rules. Unknown legal values remain versioned configuration and must be reported as `PENDING_LEGAL_VERIFICATION`.
6. All regulatory state changes are domain/application commands. Never expose arbitrary status mutation endpoints.
7. Run migration-from-zero, unit, integration and critical E2E tests before calling a Pack complete.
8. At the end of each Pack report: migrations implemented, modules/routes/APIs, tests, unresolved regulatory configuration, security/audit coverage, outbox events, and any architecture deviations. Architecture deviations should normally be empty.
9. Stop if a requested implementation would violate a frozen design rule.

## Frozen rules

- Party → Person/Company supertype.
- One permanent Facility UUID, many types/activities.
- Hierarchical admin geography supports Country → Province → District → Commune → Village.
- Case ≠ Workflow; Decision ≠ Licence ≠ Registration ≠ Certificate.
- Product ≠ Registration ≠ Package.
- Establishment Approval ≠ Operating Licence ≠ GMP.
- Finding ≠ Violation ≠ CAPA ≠ Enforcement.
- Shared Inspection Engine and shared LIMS.
- Disease Case ≠ Outbreak.
- Permit ≠ Shipment ≠ Border Inspection ≠ Quarantine ≠ Clearance ≠ Health Certificate.
- Official regulatory history is immutable/auditable.
- Files use object storage; database stores metadata only.
- External systems integrate through APIs/adapters/events, never direct core-table writes.
- AI is advisory only, never legal authority.
