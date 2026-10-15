# LVSP v1.7 — Security Model

## Core principles
1. Authentication answers: who is the user?
2. Authorization answers: what may this user do?
3. Public users are read-only and receive only explicitly public fields.
4. Staff privileges are module-scoped and action-scoped.
5. Approval is separate from data entry.
6. All sensitive write operations are audited.

## Permission examples
- veterinary_registration.read
- veterinary_registration.create
- veterinary_registration.update
- veterinary_registration.review
- veterinary_registration.approve
- veterinary_trade.read
- veterinary_trade.create
- veterinary_trade.update
- veterinary_trade.approve
- report.read
- report.export
- master_company.manage
- user_admin.manage

## Production controls
- Secure cookies / session tokens.
- CSRF-safe state-changing requests where cookie auth is used.
- Parameterized SQL only.
- Rate limiting on login endpoints.
- Failed login logging.
- No passwords stored in plain text.
- Audit events for create/update/approve/archive/user-role changes.
