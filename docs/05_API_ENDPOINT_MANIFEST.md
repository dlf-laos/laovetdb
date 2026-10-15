# API Endpoint Manifest

Base: `/api/v1`.

## Foundation

- `/auth`
- `/users`
- `/organizations`
- `/admin-units`
- `/persons`
- `/companies`
- `/facilities`
- `/services`
- `/workflows`
- `/tasks`
- `/documents`

## Regulatory core

- `/applications`
- `/cases`
- `/decisions`
- `/registrations`
- `/licenses`
- `/certificates`

Business transitions are command endpoints, for example:

- `POST /applications/{id}/submit`
- `POST /cases/{id}/assign`
- `POST /cases/{id}/decisions`
- `POST /licenses/{id}/suspend`
- `POST /certificates/{id}/revoke`

Do not allow raw status PATCH as a substitute for domain commands.

## Domain APIs

- `/products`, `/feed`
- `/inspections`, `/findings`, `/capa`, `/enforcement-cases`
- `/laboratory/samples`, `/laboratory/test-requests`, `/laboratory/results`
- `/farms`, `/animals`, `/movements`
- `/diseases`, `/disease-cases`, `/outbreaks`, `/vaccination-campaigns`
- `/trade/operators`, `/trade/permits`, `/trade/shipments`
- `/aquaculture/facilities`, `/aquaculture/stock-batches`
- `/gis`, `/reports`, `/integrations`

## API requirements

OpenAPI, request/correlation IDs, idempotency for high-value commands, server-side authorization, standardized error codes, pagination, rate limits on public/integration endpoints, audit on sensitive actions.

## v1.2 Veterinary drug controlled references
- `GET /api/v1/veterinary-drug-reference-data` — active controlled terms for Category, Dosage Group/Form, ATCvet, Distribution and Route.
- `GET /api/v1/drug-registrations/next-number?registrationType=IMPORT|DOMESTIC|REPACK` — non-reserving registration-number preview; final number is allocated server-side on create.

## Veterinary drug operational registration — v1.3

PostgreSQL/Supabase-backed staff endpoints:

- `GET /veterinary-drug-applications?regulatoryProfileId={uuid}`
- `GET /veterinary-drug-applications/reference?regulatoryProfileId={uuid}`
- `POST /veterinary-drug-applications`
- `GET /veterinary-drug-applications/{id}`
- `POST /veterinary-drug-applications/{id}/parties`
- `PATCH /veterinary-drug-applications/{id}/parties/{rowId}`
- `POST /veterinary-drug-applications/{id}/presentations`
- `PATCH /veterinary-drug-applications/{id}/presentations/{rowId}`
- `POST /veterinary-drug-applications/{id}/documents`
- `PATCH /veterinary-drug-applications/{id}/documents/{rowId}`
- `POST /veterinary-drug-applications/{id}/reviews`
- `POST /veterinary-drug-applications/{id}/registration-link`
- `POST /veterinary-drug-applications/{id}/transition`

Lifecycle status changes use `registration.transition_veterinary_drug_application(...)`; raw status PATCH is not exposed.


## Legacy registration + trade parity — v1.4

Internal DLF staff endpoints:

- `GET /legacy-parity/registration-candidates`
- `GET /legacy-parity/registration-memos`
- `POST /legacy-parity/registration-memos`
- `GET /legacy-parity/registration-memos/{id}`
- `PATCH /legacy-parity/registration-memos/{id}`
- `GET /legacy-parity/trade-coordination/{applicationId}`
- `PUT /legacy-parity/trade-coordination/{applicationId}`
- `GET /legacy-parity/reports/drugs`
- `GET /legacy-parity/reports/trade`

The custom handler enforces authenticated internal roles. Write operations require internal write roles; SIGNED/ARCHIVED status requires approving/signatory authority.

## True legacy workspaces — v1.6

- `GET /legacy-parity/annual-plan-overview?year=YYYY` — annual plan summary using actual cleared quantity / remaining balance analytics.

## Private document intake pilot

- GET/POST `/document-intake` — owner/admin list and create upload-first draft.
- GET `/document-intake/{id}` — authorized draft, evidence metadata and AI suggestions.
- POST `/document-intake/{id}/documents` — bounded upload and audited attachment.
- GET `/document-intake/{id}/documents/{attachmentId}` — authorized no-store download.
- POST `/document-intake/{id}/extract` — opt-in server AI extraction; explicit disclosure consent and version required.
- POST `/document-intake/{id}/review` — versioned human confirmation; no official registration/approval.

Requires registration staff role and draft ownership (or system/security administrator). PostgreSQL migration 000940 is required. See INTAKE_PILOT_STATUS_LO.md for limits and activation requirements.
