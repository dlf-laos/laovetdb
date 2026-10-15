# Claude Blocker Policy

Claude should continue automatically unless one of these is true:
1. The requested action would violate a frozen architecture rule.
2. A destructive migration/data operation cannot be made safe or tested.
3. A secret/credential is mandatory for the exact next runtime gate and no local/mock/test substitute exists.
4. An official legal value is essential to a regulatory decision and cannot be left as versioned configuration/placeholder.
5. Existing source changes conflict materially and there is no safe merge strategy.

The following are **not** blockers during normal implementation:
- No production Neon credential yet: use a disposable PostgreSQL runtime for development tests; leave target-Neon validation pending.
- No SMS/email provider: implement adapter + fake/test provider.
- No official e-Certificate partner endpoint: implement adapter/contract + mock partner.
- No official PKI: implement signature-provider interface and a non-production test adapter.
- Missing fee/validity/deadline/penalty values: use configuration records marked `PENDING_LEGAL_VERIFICATION`.
- Missing final Lao geography dataset: keep import templates and test hierarchy with synthetic data; production import remains pending.
