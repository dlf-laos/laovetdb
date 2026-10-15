# LVSP v1.4 — Legacy Registration + Trade Parity

ຊຸດນີ້ດຶງ feature ຫຼັກຈາກ Legacy Veterinary HTML/database ເຂົ້າ LVSP ໂດຍບໍ່ສ້າງ architecture ໃໝ່ ແລະບໍ່ລຶບຂໍ້ມູນເກົ່າ.

## 1. ໃບກິດສຳພັນທະບຽນຢາ — many registrations per memo

- 1 ໃບກິດສຳພັນ ເລືອກຫຼາຍຕົວຢາ/ຫຼາຍທະບຽນໄດ້.
- 1 product/formulation = 1 ແຖວໃນໃບກິດສຳພັນ.
- ຖ້າ product ມີຫຼາຍ presentation/package, ຜູ້ໃຊ້ເລືອກ sub-registration ທີ່ຈະເອົາເຂົ້າໃບໄດ້.
- sub-registration, strength ແລະ pack description ຖືກຈັດກຸ່ມໃນ registration cell ຂອງ product ນັ້ນ.
- ຮອງຮັບ search, company/category/status filters, select-all-filtered, clear, group by company.
- ຮອງຮັບຈຸດປະສົງ approve / forward / consider / opinion / report.
- ບັນທຶກ header, recipient, subject, staff/signatory names ແລະ status.
- Print/PDF + Word.
- Official-history snapshot ເກັບຢູ່ PostgreSQL; signed/archived memo ຖືກປ້ອງກັນຈາກການ overwrite ໃນ API.

Database:

- `registration.veterinary_drug_internal_memo`
- `registration.veterinary_drug_internal_memo_item`

## 2. Import / Export / Transit coordination review

ຄຳຮ້ອງ trade ມີ persistent coordination sheet ທີ່ກວດ:

1. IET 1 / IET 4 application/form
2. origin export permit
3. IET 2 / IET 3 analysis/report
4. Invoice & Packing List
5. GMP / HACCP
6. health / quality certificate
7. drug/product registration if applicable
8. other documents

ສະຖານະຄວາມຄົບຖ້ວນ: Pending / Present / Missing / Not applicable.

ສະຖານະຄຸນນະພາບ: Pending / Correct / Incorrect / Policy / Not applicable.

ຮອງຮັບ reference number, notes, reviewer, comment, management comment, Print/PDF + Word.

Database:

- `lookup.regulatory_coordination_requirement`
- `trade.application_coordination_sheet`
- `trade.application_coordination_item`

## 3. Shared Regulatory Report Builder

Data sources:

- Veterinary Drug Registration
- Trade / Permit

Features:

- selectable columns
- Date Basis
- From / To
- Search
- Status, Category/Movement Type, Company filters
- quick periods: This Month, Last Month, This Quarter, This Year, All
- Portrait / Landscape
- Print/PDF
- Word
- Excel
- CSV
- official Lao PDR / Ministry / DLF report header, period, filters, count, print date and signature area

Analytics views:

- `analytics.v_veterinary_drug_registry_report`
- `analytics.v_veterinary_trade_permit_report`

## 4. Entry points in current LVSP

Drug Registration detail:

- `🗂 ແຟ້ມພິຈາລະນາ`
- `📄 ໃບກິດສຳພັນ` → opens the new multi-registration memo picker
- `📊 ລາຍງານ`
- registration certificate print remains unchanged

Trade / Import Application detail:

- `📋 ໃບກິດສຳພັນ / ກວດເອກະສານ`
- `📊 ລາຍງານ`
- existing permit/notification print remains unchanged

Navigation also exposes:

- Registration Memos
- Regulatory Reports

## 5. Non-destructive rule

Migration `000810_legacy_registration_trade_parity.sql` does not drop tables or delete existing regulatory records. Existing LVSP v1.3 veterinary-drug operational workflow and 000790 annual-plan extension remain foundations and are not replaced.
