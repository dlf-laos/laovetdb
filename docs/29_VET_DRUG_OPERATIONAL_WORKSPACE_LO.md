# LVSP v1.3 — Veterinary Drug Operational Workspace

## ເປົ້າໝາຍ

v1.3 ເຊື່ອມ database foundation `000800_vet_drug_registration_operational.sql` ເຂົ້າກັບ Staff Web UI ແລະ API. ບໍ່ສ້າງ schema ໃໝ່, ບໍ່ rerun 000800, ບໍ່ rewrite legacy drug profiles.

## 6 ສ່ວນໃນ Operational Dossier

1. Application / Product & lifecycle
2. Parties / Company Master / Site / frozen snapshots
3. Presentations / packages / sub-registration preparation
4. Dossier / evidence metadata / document verification
5. Screening & technical reviews
6. Decision / official registration link / immutable action history

## API

- `GET /api/v1/veterinary-drug-applications?regulatoryProfileId=...`
- `GET /api/v1/veterinary-drug-applications/reference?regulatoryProfileId=...`
- `POST /api/v1/veterinary-drug-applications`
- `GET /api/v1/veterinary-drug-applications/{id}`
- `POST/PATCH .../parties`
- `POST/PATCH .../presentations`
- `POST/PATCH .../documents`
- `POST .../reviews`
- `POST .../registration-link`
- `POST .../transition`

## ກົດຄວາມປອດໄພ/ກົດລະບຽບ

- Application status ບໍ່ຖືກ PATCH ໂດຍກົງ. API ເອີ້ນ `registration.transition_veterinary_drug_application(...)`.
- APPROVE / REJECT / REGISTER ຈຳກັດໃຫ້ `APPROVING_AUTHORITY` ຫຼື `SYSTEM_ADMIN`.
- Screening / technical review commands ຈຳກັດຕາມ reviewer roles.
- Official registration link ເຮັດໄດ້ຫຼັງ Application = `APPROVED` ເທົ່ານັ້ນ.
- Dossier legal requirement ຄ່າເລີ່ມຕົ້ນ = `PENDING_LEGAL_VERIFICATION`; ບໍ່ hard-code ຄ່າທຳນຽມ, deadline, approving authority ຫຼື certificate wording.
- Writes ທີ່ສຳຄັນຖືກ transaction + `audit.event` + `integration.outbox_event`.
- ບໍ່ມີ hard delete path ສຳລັບ regulatory history.

## Legacy Data

Existing `product.product_regulatory_profile` records ຍັງຢູ່ຄືເກົ່າ. ເມື່ອກົດ **🗂 ແຟ້ມພິຈາລະນາ** ຈາກ Drug Detail, user ສາມາດສ້າງ operational application ທີ່ link ຫາ profile ເກົ່າ ແລະ seed ຂໍ້ມູນ party/package snapshots ໂດຍບໍ່ປ່ຽນ legacy record.

## Scope Boundary

v1.3 ຍັງບໍ່ອອກ official certificate/QR ໃໝ່. `Registration != Certificate` ຍັງຖືກຮັກສາ. Certificate + QR issuance ແມ່ນ phase ຕໍ່ໄປ.
