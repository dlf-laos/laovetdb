# LVSP v1.12 — DVS Domain + DLF/Single Window Integration Blueprint

Status: Pre-Neon / additive architecture
Mandate basis: DVS 2025 provisional; update when the 2026 mandate is available.

## Core rule
LVSP remains the Veterinary Services domain platform. It does not absorb unrelated work of other DLF divisions/centers.

Each business service is independent from the current organization chart:
- service identity stays stable;
- responsibility is effective-dated;
- lead/participant/external-owner status can change without rewriting historical cases.

## Responsibility classes
- DVS_LEAD
- DVS_PARTICIPANT
- EXTERNAL_OWNER
- UNCONFIRMED

## Provisional 2025 examples
- Veterinary drug registration: DVS_LEAD
- Veterinary drug/device trade: DVS_LEAD
- Pet movement: DVS_LEAD
- Animal product trade: DVS_PARTICIPANT for veterinary/sanitary/risk functions
- Live animal trade: DVS_PARTICIPANT; joint/shared with Livestock Division
- Animal feed trade: UNCONFIRMED pending updated mandate
- Laboratory/sample testing: EXTERNAL_OWNER; LVSP stores referral/result references only

## Future integration boundary
LVSP must not directly access another agency's database.

Integration path:
DLF Portal / DLF Gateway -> LVSP API
                         -> Livestock API
                         -> Fisheries API
                         -> Lab API
                         -> Customs / Lao National Single Window

## Stable integration primitives
- external system registry
- external identifiers
- versioned APIs (/api/v1/...)
- correlation/message IDs
- generic message envelope
- e-Cert exchange remains under the 000850 certification architecture
- no external URL, credential or legal issuing authority is hard-coded

## Hosting portability
Development/pilot:
Cloudflare/free web hosting -> LVSP API -> Neon PostgreSQL

Future production:
Official DLF subdomain -> approved DLF infrastructure -> LVSP API -> DLF PostgreSQL

The application must remain standard-PostgreSQL portable so Neon can be replaced by DLF PostgreSQL without rebuilding the business architecture.
