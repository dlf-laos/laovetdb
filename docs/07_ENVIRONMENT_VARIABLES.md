# Environment Variables

Never commit secret values.

## Application

- `NODE_ENV`
- `APP_BASE_URL`
- `API_BASE_URL`
- `LOG_LEVEL`

## Database

- `DATABASE_URL` — runtime connection, normally pooled where appropriate
- `DATABASE_MIGRATION_URL` — direct/migration connection with separate privileges

## Identity

- `AUTH_MODE` — `demo` for isolated local development, `database` for individual LVSP PostgreSQL users, or `oidc` when an external identity provider is configured.
- `LVSP_AUTH_SECRET` — HMAC signing secret for LVSP access tokens. Production requires at least 32 characters; store as a secret, never in Git.
- `LVSP_BOOTSTRAP_ADMIN_USER` / `LVSP_BOOTSTRAP_ADMIN_PASSWORD` — demo/local mode only; never use in production.

- `OIDC_ISSUER_URL`
- `OIDC_CLIENT_ID`
- `OIDC_CLIENT_SECRET_REF`
- `OIDC_AUDIENCE`

## Storage

- `OBJECT_STORAGE_ENDPOINT`
- `OBJECT_STORAGE_BUCKET`
- `OBJECT_STORAGE_REGION`
- `OBJECT_STORAGE_ACCESS_KEY_REF`
- `OBJECT_STORAGE_SECRET_KEY_REF`

## Notifications

- `EMAIL_PROVIDER`
- `EMAIL_CREDENTIAL_REF`
- `SMS_PROVIDER`
- `SMS_CREDENTIAL_REF`

## Integration

- `INTEGRATION_SECRET_STORE`
- `PUBLIC_VERIFY_BASE_URL`

## Security/observability

- `APP_ENCRYPTION_KEY_REF`
- `ERROR_TRACKING_DSN_REF`
- `OTEL_EXPORTER_ENDPOINT`

Runtime roles and migration roles must use least privilege. Direct production database credentials are never exposed to frontend applications.
