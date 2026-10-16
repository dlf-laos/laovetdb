# V31 continuation assessment — 16 October 2026

Reviewed the user-supplied DLF_Vet_Admin_Trade_v31_Integrated.html without executing its scripts. It is approximately 2.1 MB and embeds a separate trade HTML document (~426 k characters) alongside the registry and another Vet Suite implementation. Storage paths include localStorage and IndexedDB; an optional legacy online adapter does not establish that browser records have been synchronized to the current Neon schema. The HTML source is not a backup of every record saved in its browser.

Continue the existing LVSP monorepo with two operational workspaces, shared company/product/presentation masters, server authentication, PostgreSQL and audit. Do not publish an independent iframe application with a second browser database.

| V31 area | Existing continuation / change |
|---|---|
| Registry, presentations, compositions, status, dossier | Existing drug registration workspace and detailed registration API retained |
| Annual plans, permits, mixed items, clearance, printing, trade reports | Existing trade workspace retained |
| Actual trade item → exact registered presentation | New ledger lookups link existing item, product and presentation IDs; snapshot registration details |
| Unregistered / not yet linked products | Explicit surveillance record without fabricating a registration or granting regulatory eligibility |
| ANIMUSE calculations | Server validates actual packs, exact content and per-ingredient strength; explicit percent basis, IU evidence, mass basis and conversion evidence |
| Data quality | Draft/review/void, optimistic versions, duplicate document-line-movement keys, duplicate ingredient detection, audit in same transaction |
| Reporting | Reviewed movement-date cohorts, ingredient/class and registration-linkage summaries, separate re-exports/exports/transit; review CSV |
| Historical browser records | Must reconcile actual exports from the user's working browser; embedded seed data are not silently imported as operational records |
| Official WOAH submission | Not automatic. Validate the current reporting template, national coverage, stocks, exports and source overlap before submission |

Legacy risks corrected for the new AMU ledger: approved/requested quantities must not stand in for actual clearance; no first-presentation fallback; missing basis does not mean per-pack; percent basis is explicit; missing and unmapped substances remain pending instead of zero. Known exact structured composition can prefill fields, but evidence and human review remain required.

No production database migrations were applied. Migration 000950 was tested on a child validation branch, then applied atomically with its checksum to the existing isolated Preview logical database. Synthetic lifecycle tests run only on the child branch and leave voided, auditable records. Production legacy deployment and its root GitHub Pages index are preserved while the modern source is verified.

Local runtime uses the existing app and Neon Preview through encrypted WebSocket transport. No new password was set by the agent. Secrets are excluded from source, GitHub and deployment archives. The original supplied HTML remains a local private reference, not an additional public data bundle.

References: WOAH AMUse Guide and conversion annex (2022); WOAH 2025 AMU report discussion of duplicate source counting. The methodology does not claim regulatory approval, certification of international compliance, or measurement of actual administration to animals.
