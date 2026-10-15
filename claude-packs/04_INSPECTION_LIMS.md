# Development Pack 04 — Inspection, Compliance, Enforcement & National LIMS

## Goal
Implement one reusable inspection engine and one shared laboratory information management system.

## Database scope
Migrations `000200`–`000248`.

## Inspection rules
- Programs/checklists are versioned/effective-dated.
- Inspection Case ≠ Visit.
- Evidence is separately auditable and points to object-storage documents.
- Finding ≠ Violation ≠ CAPA ≠ Enforcement.
- CAPA has due dates, actions, evidence and verification.
- Enforcement actions require an authorized regulatory decision; risk/AI does not impose sanctions.

## LIMS rules
- Laboratory is a Facility extension.
- Sample → custody history → request → work order → method → result version → validation → approval.
- Approved result versions are immutable; correction creates a superseding version.
- Inspection and other domains reference trusted lab results; never duplicate them.
- Equipment/calibration/quality events are part of LIMS.

## Field requirements
Design inspection data capture for offline sync, GPS, photos, signatures and sample barcodes without weakening server-side validation.

## Acceptance
- One checklist engine can serve multiple domains.
- Historical inspection references the exact checklist version used.
- Chain-of-custody history is append-oriented.
- Approved lab result update attempts fail.
- CAPA and enforcement/appeal journeys pass tests.
