# User Action Required — Only These Inputs Need to Come From the Project/User

Claude Code should **not** stop early for these unless they are required by the current runtime gate. It should implement provider-neutral adapters/mocks first.

## Needed before target Neon staging validation
- `DATABASE_MIGRATION_URL` for an empty/non-production Neon staging database, or permission to create/use an equivalent disposable PostgreSQL runtime.
- Runtime `DATABASE_URL` using least-privilege application credentials when available.

## Needed before real document storage testing
- Object-storage provider/bucket/endpoint and secret references. Until then use a test/local adapter.

## Needed before real login/SSO acceptance
- OIDC issuer/client/audience and agreed government/enterprise identity provider. Until then use a development identity adapter that does not change domain models.

## Needed before real messaging/e-signature/integration acceptance
- SMS/email provider details.
- Digital signature/PKI provider or official trust framework.
- Customs/NSW/e-Certificate/partner API specifications, credentials and agreements where officially available.

## Needed before regulatory UAT/production
- Authoritative current Lao administrative units/codes, including Commune/ຕາແສງ where officially established.
- Verified legal instruments and service rules.
- Official fees, validity periods, competent approval/signature authorities, deadlines, penalties and final certificate wording/templates.
- Approved organization/user/role assignments and delegation rules.

## Needed before production release
- Target domain/hosting/infrastructure decisions and production secrets.
- Named UAT/business owners and approval to release.
- Backup/restore, security and production-readiness sign-off.

Never paste real production secrets into documentation or source control. Supply them through the deployment environment/secret manager.
