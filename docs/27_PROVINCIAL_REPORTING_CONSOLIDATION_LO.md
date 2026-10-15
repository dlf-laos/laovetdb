# LVSP Provincial Veterinary Reporting & National Consolidation

## ຈຸດປະສົງ

Module ນີ້ຮອງຮັບວຽກປະຈຳຂອງພະແນກສັດຕະວະແພດ: ຮັບບົດລາຍງານຈາກແຂວງທີ່ອາດເປັນ Word, PDF, Scan ຫຼື Excel; ບັນທຶກສະເພາະຕົວຊີ້ວັດທີ່ DVS ຕ້ອງການ; ກວດຢືນຢັນ; ສັງລວມລາຍເດືອນ/ປີ; ແລະສ້າງ draft ສຳລັບບົດລາຍງານຂຶ້ນກົມ.

ການອອກແບບໃຊ້ຕົວຢ່າງຈິງທີ່ຜູ້ໃຊ້ສົ່ງມາເປັນ business source:

- Excel ສັງລວມຂອງ DVS ເປັນ Data Dictionary ສຳລັບຕົວຊີ້ວັດ.
- ບົດລາຍງານອາທິດ/ເດືອນຈາກແຂວງເປັນ Source Document.
- ບົດສະຫຼຸບປະຈຳເດືອນ 7/2026 ຂອງພະແນກເປັນ Output Pattern ສຳລັບ monthly consolidation.

## ຫຼັກການອອກແບບ

1. ມີ menu ໃໝ່ພຽງອັນດຽວ: **ລາຍງານແຂວງ / Provincial Reporting**. ຂ້າງໃນແບ່ງເປັນ Inbox, Data Entry, Monthly Summary ແລະ Assignments (Admin) ເພື່ອບໍ່ໃຫ້ sidebar ສັບສົນ.
2. North/Central/South ແມ່ນ work-allocation configuration ສາມາດປ່ຽນໄດ້; ບໍ່ແມ່ນການແທນ official geography ໃນ `master.admin_unit`.
3. ບົດລາຍງານຕົ້ນສະບັບແລະຂໍ້ມູນທີ່ extract ອອກມາເປັນຄົນລະ entity. ຈຶ່ງຮັກສາ traceability ໄດ້ວ່າຕົວເລກມາຈາກບົດໃດ.
4. ສັງລວມເອົາສະເພາະ `VERIFIED` + `include_in_consolidation=true`.
5. ປ້ອງກັນ double counting: ຖ້າ Monthly report ຂອງແຂວງຖືກ verify ແລະເລືອກໃຫ້ສັງລວມ, Weekly report ທີ່ຊ້ອນຊ່ວງເວລາຈະຖືກຍົກອອກຈາກ consolidation; ຖ້າ Weekly ມາ verify ຫຼັງ Monthly ກໍຈະບໍ່ນັບຊ້ຳ.
6. Verified data ບໍ່ໃຫ້ data-entry user ແກ້ໄຂໂດຍຕົງ. ການ verify ຈຳກັດໃຫ້ reviewer/management/admin roles.
7. ບໍ່ hard-delete ບົດລາຍງານ. ໃຊ້ revision/superseded ເພື່ອຮັກສາປະຫວັດ.

## Data groups ຈາກ Excel ຕົວຢ່າງ

- Vaccination: population, vaccinated, species.
- Treatment: treated animals, deaths, species.
- Import live animals for consumption.
- Import live animals for breeding.
- Import eggs for consumption/breeding.
- Import animal products.
- Export animal products.
- Transit animal products.
- Transit live animals.
- Export live animals/aquatic animals.
- Slaughter/meat inspection.
- Animal by-products.
- Checkpoint reference list.

v1.1 ເຮັດ normalized core ສຳລັບ indicators + trade statistics ເພື່ອຮອງຮັບກຸ່ມເຫຼົ່ານີ້. ລາຍລະອຽດ subtype ທີ່ຍັງບໍ່ໄດ້ຢືນຢັນຈາກທຸກແຂວງບໍ່ຖືກ hard-code ເປັນ legal rule.

## Workflow

`RECEIVED → DATA_ENTRY → READY_FOR_REVIEW → VERIFIED`

ມີ `REJECTED` ແລະ `SUPERSEDED` ສຳລັບການແກ້ຄືນ/ສະບັບໃໝ່.

## Attachment

Development build v1.1 ເກັບ source filename/reference ກ່ອນ. Binary Word/PDF/Scan ຈະເຊື່ອມເຂົ້າ shared Document/Object Storage ເມື່ອ online object-storage provider ຖືກ configure; ບໍ່ເກັບ binary ເຂົ້າ PostgreSQL.

## ການປິດ Module ຖ້າບໍ່ເໝາະ

Admin Center → Settings → `REPORTING_MODULE_ENABLED` = Off. Menu ຈະຫາຍໄປຈາກ UI ແຕ່ data ແລະ migration ຍັງຖືກຮັກສາໄວ້. ການປິດ feature ດີກວ່າ DROP table ເພາະບໍ່ທຳລາຍປະຫວັດ.
