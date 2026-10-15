# LVSP v0.9 — Annual Import Plan Operational Core

## ຈຸດປະສົງ

Patch ນີ້ສືບຕໍ່ຈາກ `repo 2` ໂດຍບໍ່ reset database ແລະບໍ່ລຶບ migration/feature ເກົ່າ. ເປົ້າໝາຍແມ່ນຍົກ Annual Import Plan ຈາກ record ພື້ນຖານໃຫ້ເປັນ operational record ທີ່ສາມາດຕໍ່ໄປຫາ Import Application, Border Clearance ແລະ Balance Tracking ໄດ້.

## 1. Annual Plan Header

ເພີ່ມ field ສຳລັບອ້າງອີງເອກະສານທາງການ:

- Application Ref. No. / Date
- Approval No. / Date
- Decision No. / Date
- Valid From / Valid To
- Approved By
- Approval Conditions
- Company name/address snapshot
- Cancellation reason/date
- Current approved version number

ລະບົບບໍ່ auto-calculate `valid_to` ເອງ; ວັນມີຜົນ/ໝົດອາຍຸຕ້ອງມາຈາກ record/policy ທີ່ອະນຸມັດ.

## 2. Mixed Plan + Official Group Lines

1 Annual Plan ສາມາດມີລາຍການປະສົມ:

- Medicine
- Vaccine
- Biological
- Veterinary Device / Equipment
- Diagnostic Kit
- Other Veterinary Product

ແຕ່ລະ line ຮອງຮັບ `ITEM` ແລະ `SUMMARY_GROUP` ເພື່ອຮັກສາຮູບແບບລາຍການລະອຽດ ຫຼື ແຖວສະຫຼຸບ/ກຸ່ມຕາມເອກະສານຕົ້ນສະບັບ. ມີ item code, group code/name, item count, pack count, quantity, unit ແລະ value.

## 3. Controlled Lifecycle

Annual Plan status ບໍ່ໄດ້ປ່ຽນຜ່ານ arbitrary form field. ການປ່ຽນສະຖານະໃຊ້ command API:

- DRAFT → SUBMITTED
- SUBMITTED → DRAFT
- SUBMITTED → APPROVED
- DRAFT/SUBMITTED/APPROVED → CANCELLED

DRAFT ເທົ່ານັ້ນທີ່ແກ້ header/items ໄດ້. APPROVED/CANCELLED ຖືກ lock ໃນ operational UI.

## 4. Approved Snapshot / Auditability

ເມື່ອ APPROVED:

- ສ້າງ immutable `trade.import_plan_version`
- copy ລາຍການເຂົ້າ `trade.import_plan_item_version`
- snapshot ຊື່/ທີ່ຢູ່ບໍລິສັດ
- hard delete ຂອງ approved snapshots ຖືກປ້ອງກັນ

ການອອກແບບນີ້ເຮັດໃຫ້ເອກະສານ/record ເກົ່າບໍ່ປ່ຽນຕາມ Master Data ພາຍຫຼັງ.

## 5. Balance Tracking Rule

View `analytics.v_import_plan_item_balance` ຄິດ:

`Remaining = Planned Quantity - Actual Cleared Quantity`

Actual Cleared Quantity ມາຈາກ `trade.import_application_item.cleared_quantity` (fallback `cleared_packs`) ຂອງ application item ທີ່ link ກັບ `plan_item_id`.

**ບໍ່ຕັດຍອດເມື່ອ application/permit ພຽງແຕ່ Approved.**

ຖ້າ plan line ດຽວຖືກໃຊ້ໃນຫຼາຍ Import Application/cleared item, ຍອດ actual ຈະຖືກ sum ເຂົ້າຫາ plan line. ສ່ວນ multiple clearance events ພາຍໃຕ້ permit/application item ດຽວ ຈະຖືກສ້າງເປັນ Border Clearance ledger ໃນ priority ຕໍ່ໄປ ເພື່ອບໍ່ຄາດເດົາ event model ລ່ວງໜ້າ.

## 6. Import Application Linkage

Bulk import/preview ຂອງ Import Application ຈະພະຍາຍາມ match plan line ຕາມລຳດັບ:

1. Package ID
2. Product ID
3. Registration No. + Package Description
4. Registration No.
5. Exact Item Name

ລະບົບ auto-link ສະເພາະເມື່ອ Annual Plan ຢູ່ສະຖານະ **APPROVED** ແລະພົບ **1 unique match**. ຖ້າ plan ຍັງບໍ່ APPROVED ຈະ flag `PLAN_NOT_APPROVED_REVIEW_REQUIRED`. ຖ້າ requested quantity ເກີນ remaining balance ຈະ flag `OVER_PLAN_REVIEW_REQUIRED`.

ປັດຈຸບັນ flag ນີ້ເປັນ **warning/review**, ບໍ່ໄດ້ hard-block ເພາະ policy ສຸດທ້າຍວ່າຈະ warning ຫຼື block ຕ້ອງໄດ້ກຳນົດໃຫ້ຊັດ.

## 7. UI Changes

Annual Plan modal ປັບເປັນ:

- full header/reference fields
- dynamic `+ Add Plan Line`
- multiple mixed items
- product/device link per line
- grouped/summary lines
- create/update whole plan in one transaction

Annual Plan detail ສະແດງ:

- Plan Lines
- Planned Quantity
- Actual Cleared
- Remaining Balance
- Planned Value
- per-line balance
- approved snapshot history
- workflow action buttons

## 8. Database Migration

Migration:

`database/migrations/000780_annual_import_plan_operational.sql`

ເປັນ additive/non-destructive migration. ບໍ່ລຶບ Neon, ບໍ່ reset database ແລະບໍ່ແກ້ migration ເກົ່າ.

## 9. ສິ່ງທີ່ຍັງບໍ່ຖືກຕັດສິນໃນ v0.9

- policy ສຸດທ້າຍສຳລັບ over-plan: warning vs hard block
- amendment workflow ທີ່ມີ plan items ຖືກອ້າງອີງໂດຍ clearance ແລ້ວ (ຕ້ອງ preserve historical linkage)
- carry-forward / adjustment policy
- Border Clearance command + evidence + QR verification workflow (priority ຕໍ່ໄປ)

ສ່ວນເຫຼົ່ານີ້ຈະບໍ່ຖືກຄາດເດົາຫຼື hard-code ໂດຍພະລະການ.
