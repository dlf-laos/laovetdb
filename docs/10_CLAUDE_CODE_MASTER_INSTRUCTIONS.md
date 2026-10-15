# Claude Code Master Instructions — LVSP

You are implementing the Lao Veterinary Services Platform (LVSP) from an approved architecture baseline.

## Core architecture

- TypeScript monorepo.
- Modular Monolith First; service-ready by design.
- React/Next.js-style frontend and NestJS-style modular backend.
- Neon PostgreSQL, SQL-first schema and migrations.
- Do not put business tables in `public`.
- ORM/query libraries may be used for application access, but they must not redefine or silently mutate the approved enterprise schema.

## Immutable design rules

1. `master.party` is the supertype for Person and Company.
2. Do not create duplicate master tables for importer, exporter, manufacturer, distributor, applicant or farm owner. Use Party Roles.
3. Administrative geography is one hierarchical `master.admin_unit` model: Country → Province → District → Commune → Village.
4. One physical facility has one permanent UUID and may have many types/activities.
5. Application/Case and Workflow Instance are separate concepts.
6. Decision, Licence, Registration, Certificate and PDF are separate concepts.
7. Product, Registration and Package are separate concepts.
8. Establishment Approval, Operating Licence and GMP are separate lifecycles.
9. Inspection Case, Visit, Finding, Violation, CAPA and Enforcement are separate concepts.
10. Use one shared Inspection Engine and one shared LIMS.
11. Approved laboratory results are immutable; corrections create a new version.
12. Disease Case and Outbreak are separate.
13. Trade Permit, Shipment, Border Declaration, Inspection, Quarantine, Clearance and Health Certificate are separate.
14. Files use object storage; PostgreSQL stores metadata, object key and checksum.
15. Do not hide core relational data in JSONB.
16. Official regulatory history is never hard-deleted.
17. External systems never write directly to core DB tables.
18. Business state transitions use command/service operations, not direct status PATCH.
19. Server-side authorization uses RBAC + ABAC + scope.
20. AI may assist but never issue regulatory decisions.

## Build order

Implement Packs 01 through 08 in order. At the end of each Pack:

- run migrations from zero;
- run automated tests;
- produce migration inventory;
- produce schema summary;
- produce API inventory;
- list unresolved regulatory configuration;
- list deviations from architecture (normally empty);
- stop if a core architecture rule would be violated.

## Regulatory unknowns

Do not invent legal requirements, fees, validity periods, approval authorities, inspection frequency, severity bands, disease restrictions, lab limits or certificate formats. Model unknown regulatory values as versioned configuration and mark them pending legal verification.

## Definition of done

A Pack is not done merely because screens render. It is done only when migrations, constraints, authorization, audit, outbox events, APIs and tests are implemented and passing.
