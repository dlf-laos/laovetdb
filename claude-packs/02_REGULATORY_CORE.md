# Development Pack 02 — Regulatory Case, Decisions, Registration & Licensing

## Goal
Implement the universal regulatory backbone on top of Pack 01.

## Database scope
Migrations `000100_casework.sql`, `000110_registration.sql`, `000120_licensing.sql`, `000130_certificate_foundation.sql`.

## Domain rules
- Regulatory Case and Workflow Instance are separate.
- Applicant/holder references `master.party`.
- Regulatory decisions are immutable; amendment/review creates linked new decisions.
- Registration and Licence preserve historical identity through lifecycle actions.
- Licence holder and regulated Facility are separate references.
- Certificate is structured regulatory data; PDF/document is a generated representation.

## Command APIs
Implement commands such as submit/withdraw application, assign case, request/respond information, make decision, renew/vary/suspend registration, renew/amend/suspend/restore/revoke licence, issue/revoke certificate. Do not expose direct status mutation.

## Cross-cutting
Every sensitive command must perform authorization, workflow/state validation, audit logging and outbox-event creation within the appropriate transaction boundary.

## Acceptance
- Application → review → decision → registration/licence/certificate journey passes integration tests.
- Decision immutability is tested.
- Raw status PATCH cannot bypass state machine.
- Historical lifecycle actions remain queryable.
