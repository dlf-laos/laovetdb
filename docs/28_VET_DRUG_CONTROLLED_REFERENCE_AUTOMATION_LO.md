# LVSP v1.2 — ທະບຽນຢາ: Controlled Reference Data + Regulatory Automation

## ເປົ້າໝາຍ
ຮັກສາຈຸດດີຂອງ `admin(4).html` ແຕ່ບໍ່ນຳຄວາມຊັບຊ້ອນຂອງ localStorage/ຂໍ້ມູນຊ້ຳກັບຄືນມາ. Company/Site Master, Neon, audit, presentation versioning ແລະ shared LVSP architecture ຍັງເປັນຖານຫຼັກ.

## ນຳກັບມາຈາກຖານເກົ່າ
- Category ເປັນ dropdown.
- Dosage Group → Dosage Form ເປັນ dependent dropdown.
- ATCvet ກັ່ນຕາມ Category ແລະຮັກສາ legacy value ຖ້າຄ່າເກົ່າບໍ່ຢູ່ໃນ list.
- Distribution: POM / OTC / Controlled.
- Route ເປັນ controlled dropdown.
- Registration No. ສ້າງ auto ຕາມ `ຢສ-[F/L/R]-YYYYMM-NNNN`, Imported=F, Domestic=L, Repacked=R; Imported ຮັກສາ sequence floor 0200 ຕາມ legacy rule.
- Registration No. ລັອກໂດຍ default ແຕ່ພະນັກງານສາມາດ Manual Edit; source ຖືກເກັບ AUTO/MANUAL/LEGACY.
- DLF Date = Issue Date. Expiry Date = Issue Date + Valid Years (ຮອງຮັບ 29 Feb clamp).

## ສິ່ງທີ່ບໍ່ນຳກັບມາ
- ບໍ່ກັບໄປໃຊ້ company ແບບ free-text ເປັນ source of truth; ໃຊ້ Company Master + Site/Facility.
- ບໍ່ເກັບ reference list ຢູ່ແຕ່ JavaScript; Neon table `lookup.veterinary_drug_reference_term` ເປັນ configurable source.
- ບໍ່ລຶບ legacy value ທີ່ບໍ່ກົງ list ໃໝ່; UI ສະແດງ “Legacy” ເພື່ອໃຫ້ review.
- ບໍ່ປ່ຽນ Product Core → Presentations → Composition model ທີ່ v0.5+ ປັບດີແລ້ວ.

## ມາດຕະຖານ
ATCvet ໃຊ້ເປັນການຈັດຫມວດ/reference ທີ່ update ໄດ້. Dosage form/route ຖືກອອກແບບໃຫ້ map ກັບ controlled standard terms ໄດ້. ຫ້າມອ້າງວ່າ LVSP ໄດ້ຮັບການ certify ຈາກ WHO/EDQM.
