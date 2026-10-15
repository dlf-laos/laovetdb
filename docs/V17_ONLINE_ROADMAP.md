# LVSP v1.7 — Online Production Roadmap

Goal: put LVSP online without stopping continued development.

## Environment separation
- Production: staff use this for daily operational work.
- Staging/Development: changes are built and tested here first.
- Never test destructive migrations directly against Production.

## Online architecture target
- Cloudflare Worker: LVSP web/API runtime.
- Neon PostgreSQL: LVSP database.
- Managed authentication: individual user accounts and sessions.
- Public read-only area: selected non-sensitive information only.

## Release flow
1. Develop in LVSP_V17_ONLINE_AUTH.
2. Run automated tests locally.
3. Test against staging database/branch.
4. Back up Production.
5. Apply additive migration(s).
6. Deploy app update.
7. Verify health, login, permissions and document printing.

## Planned roles
- PUBLIC: no login; read selected public information only.
- STAFF: login; create/edit records in assigned work area.
- REVIEWER: review and request correction.
- APPROVER: approve/authorize according to assigned module.
- ADMIN: manage users, roles and master data.

## Safety rules
- Hiding a button is not authorization. Every write API must check permission server-side.
- No hard delete for routine users. Use archive/void with audit trail.
- Do not expose DATABASE_URL, auth secrets, internal notes, applicant identity documents, or private attachments to the browser/public API.
