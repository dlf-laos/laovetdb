# LVSP modernization continuation

Private dossier intake and human review have been added to this existing monorepo. See [the Lao intake status and activation guide](docs/INTAKE_PILOT_STATUS_LO.md). Gemini is the preferred server AI provider (OpenAI remains an explicit option). The server AI adapter is implemented but live provider/object storage activation and production deployment remain pending. Confirm review does not issue an official registration.

Validation on 15 October 2026: TypeScript build and package validation passed; final regression results are recorded in the intake status guide. Production database unchanged.

## Earlier departmental release baseline

Start with [the Lao user guide](README_RELEASE_LO.md). This package preserves the existing veterinary-registration and trade source, adds monthly departmental work and budget tracking, and prepares a GitHub/Vercel deployment path.

Version: `1.12.0-release-candidate.1`. Source prepared 4–5 October 2026.

Local tests: 101 passed. All 114 migrations and baseline seeds ran on a fresh disposable PostgreSQL database. Database login, monthly summary, budget lifecycle, concurrent-update protection, audit/outbox and verified-record locks passed PostgreSQL integration checks. The existing Neon database was inspected read-only: 112 tracked migrations, no checksum mismatch; 000920 and 000930 remain pending.

Run `bash START_REVIEW.command` for a local demonstration, or `bash CHECK_RELEASE.command` for validation. Existing sensitive runtime records and environment files are excluded from the upload package. See [deployment steps](docs/RELEASE_DEPLOYMENT.md), [departmental scope/UAT](docs/DEPARTMENT_SCOPE_AND_UAT_LO.md), and [implementation report](docs/FINAL_IMPLEMENTATION_REPORT.md).

This is a release candidate. Production deployment and complete departmental workflow acceptance remain pending; wider division scope requires later approval.
