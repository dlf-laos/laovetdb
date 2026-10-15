# LVSP v0.3.0 — Neon Runtime Fix + Veterinary Drug UI Progress

## ສິ່ງທີ່ແກ້ແລ້ວ
- ແກ້ PostgreSQL mapping `inspection.case` -> `inspection.inspection_case`.
- ແກ້ `disease.case` -> `disease.disease_case`.
- ແກ້ `enforcement.case` -> `enforcement.enforcement_case`.
- ແກ້ `analytics.dashboard` -> `analytics.dashboard_definition`.
- ແກ້ audit/outbox list bug ທີ່ໃຊ້ variable `i` ທີ່ບໍ່ໄດ້ກຳນົດ.
- ກວດ PostgreSQL resource mappings 57 ລາຍການ: ບໍ່ມີ mapping ທີ່ຊີ້ໄປ table ທີ່ບໍ່ມີ.

## UI ທີ່ປັບ
- ປ່ຽນເມນູ Products ເປັນ “ທະບຽນຢາສັດ / Veterinary Drug Registry”.
- ເພີ່ມ form ທະບຽນຢາແບບແບ່ງພາກ ໂດຍອີງຈາກ admin(4).html: Product identity, dosage/use, packaging.
- ເມື່ອ Save draft ຈະສ້າງ Product Master + Product Version + Package ຜ່ານ LVSP API.
- ສະແດງ Neon PostgreSQL Staging ທີ່ sidebar ເມື່ອ storage mode = postgres; ບໍ່ສະແດງ Local Development Mode ແບບຄົງທີ່ອີກ.

## ຂອບເຂດທີ່ຍັງດຳເນີນຕໍ່
- Full admin(4) visual parity ແລະ 6-section veterinary drug registration form.
- Manufacturer/Importer assignment, ingredients/composition, target species, package versions, documents GMP/CPP/Label/Leaflet.
- Registration application/technical review/approval/registration certificate workflow.
- Veterinary product Import/Export/Transit workspace + registry eligibility pre-check.

## Validation
- TypeScript build: PASS
- Automated API/build tests: 14/14 PASS
- PostgreSQL resource-to-physical-table mapping validation: 57/57 PASS
