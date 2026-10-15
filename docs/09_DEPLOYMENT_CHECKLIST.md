# Deployment Checklist

## Before staging

- all migrations reviewed
- migrations run from zero
- seeds validated
- lint/typecheck/tests pass
- OpenAPI generated
- secrets configured outside repo
- object storage bucket/policies configured
- pooled runtime DB URL and direct migration DB URL configured

## Staging

- run full migration set
- load non-sensitive test/reference data
- run E2E critical journeys
- verify audit events/outbox/inbox
- verify document upload and QR verification
- test GIS queries if PostGIS enabled
- run permission matrix
- run performance smoke tests

## Production readiness

- protected production branch/database workflow
- backup/PITR policy confirmed
- restore rehearsal completed
- privileged roles reviewed
- MFA policy configured where available
- monitoring/error tracking enabled
- integration retry/dead-letter process tested
- data-retention configuration reviewed
- UAT signed off
- production migration plan approved

## Neon-specific operating pattern

Use an isolated staging branch and, when practical, a database branch per pull request for migration/E2E testing. Keep production protected and do not experiment manually on it.

## PWA / central-update checks

- production must use HTTPS (service workers/PWA install require a secure context outside localhost)
- verify `manifest.webmanifest`, icons and service-worker scope for Staff PWA
- verify `/field/` manifest/service worker and offline shell
- verify PWA update behavior after a new release is deployed
- never cache authenticated `/api/` responses in the service worker
- verify logout/session expiry while an installed PWA is open
- test browser support policy for Chrome/Edge and mobile browsers used by DLF

## Admin Center checks

- allow Admin Center only for approved SYSTEM_ADMIN / SECURITY_ADMIN users
- keep passwords, database URLs, API keys, OIDC secrets and private keys outside `system.platform_setting`
- review every production-editable setting and service toggle with business/system owners
- confirm audit events are written for administrative configuration changes
- connect user provisioning to the approved OIDC/SSO identity provider before production

## Provincial reporting v1.1

- [ ] Configure object storage before enabling binary provincial Word/PDF/scan upload in an online environment.
- [ ] Review North/Central/South staff allocation and official province mapping before UAT.
- [ ] Confirm which reporting indicators are mandatory and which source reports supersede weekly data for monthly consolidation.
- [ ] UAT the anti-double-counting rule using at least one province with both weekly and monthly reports.
- [ ] Confirm reviewer/management roles allowed to mark reports VERIFIED.
