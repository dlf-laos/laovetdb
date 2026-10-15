# Frontend Route Manifest

## Public

- `/`
- `/verify`
- `/verify/certificate/[token]`
- `/products`
- `/facilities`
- `/services`
- `/public-health`

## Applicant portal

- `/portal/dashboard`
- `/portal/applications`
- `/portal/applications/[id]`
- `/portal/company`
- `/portal/facilities`
- `/portal/products`
- `/portal/licenses`
- `/portal/registrations`
- `/portal/certificates`
- `/portal/trade`
- `/portal/documents`
- `/portal/notifications`

## Officer portal

- `/officer/dashboard`
- `/officer/my-work`
- `/officer/applications`
- `/officer/registries`
- `/officer/facilities/[id]`
- `/officer/products/[id]`
- `/officer/inspections`
- `/officer/laboratory`
- `/officer/animal-health`
- `/officer/trade`
- `/officer/fisheries`
- `/officer/gis`
- `/officer/reports`
- `/officer/admin`

## UX rules

Officer work is task-centric. Major entities get 360-degree views. All regulatory cases share a standard Case Workspace. Lao and English are baseline UI languages. Mobile inspection screens are offline-ready.

## v0.9 implementation note

The current zero-dependency web shell now implements the **behavioral pilot** for `/services` and `/officer/my-work` through in-app navigation (`Guided Services` and `My Work`). Public users can browse service guidance without login; authenticated users can create version-pinned guided drafts and continue into the detailed Drug Registration / Annual Plan / Import Application forms.

Canonical production URL routing remains the target for the future online portal deployment. The local `localhost:8787` shell uses one-page application state during development/staging so the route split can be introduced without changing the domain/database contracts.

## v1.0 installable application note

The staff shell is now an installable **Progressive Web App (PWA)** served from `/`. Browsers that support installation can add LVSP to the desktop/start menu while the application remains centrally deployed and updated from the LVSP server. `/field/` is a separate installable offline-first Field PWA that shares the same authenticated LVSP origin and API.

The current development shell also implements an in-app **Admin Center** for SYSTEM_ADMIN/SECURITY_ADMIN roles. It exposes non-secret platform settings, service activation/public visibility, IAM registry/roles, audit and the offline field-sync staging queue. Production canonical routes may later split these into `/officer/admin` and dedicated public/applicant hostnames without changing the underlying contracts.

## v1.1 provincial reporting implementation note

The local staff shell exposes one additional in-app navigation item, **Provincial Reporting**, representing the future officer route `/officer/reports/provincial`. It contains Inbox, Data Entry, Monthly Summary and Admin Assignments as tabs rather than separate sidebar modules. Visibility is controlled by the non-secret platform setting `REPORTING_MODULE_ENABLED` so the feature can be disabled without deleting data or schema.

## v1.2 Veterinary drug registration form
The existing `drug_registrations` route now uses controlled dependent dropdowns and DLF-date validity automation. No additional sidebar module is introduced.

## v1.3 Veterinary Drug Operational Workspace

No new sidebar route is added. From **Veterinary Drug Registration → drug detail**, staff can open **🗂 ແຟ້ມພິຈາລະນາ** with six sections: Application, Parties, Presentations, Dossier, Review, and Decision & History.


## Legacy registration + trade parity — v1.4

- Veterinary Drug Registration detail → `📄 ໃບກິດສຳພັນ`: one persistent internal memo can select many drug registrations and selected package/presentation sub-registrations.
- Navigation → `ໃບກິດສຳພັນທະບຽນຢາ`: list/open/create saved registration memos.
- Import/Export/Transit application detail → `📋 ໃບກິດສຳພັນ / ກວດເອກະສານ`: persistent 8-item legacy coordination checklist.
- Navigation → `ລາຍງານກຳກັບ`: shared Drug Registration / Trade report builder with column selection, filters, quick periods, Print/PDF, Word, Excel and CSV.

## Veterinary Drug Review-First UI — v1.4.1

- VM-1003 opens a review/checklist desk instead of the generic 8-step wizard.
- Core operator/application data is not re-entered.
- Other guided services remain unchanged.

## Workspace consolidation — v1.5

- Drug Registration toolbar → Registration Memo Center.
- Navigation → Central Reports: Work Area → Report Type → filters/columns → preview/export.
- Duplicate detail-level report buttons removed.
- A4 memo and certificate print pipeline hardened.
- Disabled Provincial Reporting queue hidden from My Work.

## True legacy workspaces — v1.6

- Veterinary Drug Registration → dedicated Registry + Dossier/Review workspace.
- Import · Export · Transit → one consolidated workspace for Plans & Balance, Applications/Permits, Clearance, and ANIMUSE/AMR.
- Provincial Reporting and helper trade resources are hidden from sidebar, not deleted.
- Company Master, Product Master, and Central Reports remain shared modules.
