# LVSP v0.5.0 — Priority Veterinary Products Complete

ຈຸດປະສົງ: ປັບລະບົບທະບຽນຢາ ແລະ ການນຳເຂົ້າໃຫ້ຮອງຮັບວຽກຈິງ.

## ສິ່ງທີ່ເພີ່ມ
- ຟອມທະບຽນຢາລະອຽດຕາມ admin(4): Product Core, withdrawal, holder/importer/manufacturer, applicant/business, regulatory information.
- 1 ຢາ = ຫຼາຍ Packaging / Presentation; ແຕ່ລະ presentation ມີ sub-code, strength, basis, pack, target, composition.
- ຍ້າຍ legacy data ຈາກ admin(4) seed records ເຂົ້າ Neon ແບບ idempotent (ບໍ່ລຶບຂໍ້ມູນເກົ່າ, ບໍ່ສ້າງຊ້ຳຖ້າ registration no. ມີແລ້ວ).
- Annual Import Plan: Download Excel Template + Upload Excel + Preview/Validate + Commit.
- Import Application: Download Excel Template + Upload Excel + Preview/Validate + Commit.
- ຮອງຮັບ 60–200+ rows ໃນໄຟລ໌ດຽວ.
- Mixed items ໃນ plan/application ດຽວ: medicine, vaccine, biological, device, diagnostic kit, other.
- ລາຍການຢາທີ່ຫາບໍ່ພົບໃນ registry ບໍ່ຖືກລຶບ: ເກັບໄວ້ແລະ flag REVIEW_REQUIRED.
- ກວດ registration status/expiry ອັດຕະໂນມັດຕອນ import application.
- ເກັບ source filename, row number, source payload ເພື່ອ audit.

## Excel headers
ປະເພດ | ຊື່ (ລາວ) | ຊື່ (English) | ເລກທະບຽນ | ຂະໜາດບັນຈຸ | ຈຳນວນ | ໜ່ວຍ | ມູນຄ່າ USD | ຜູ້ຜະລິດ | ປະເທດຜະລິດ | Batch | ວັນຜະລິດ | ວັນໝົດອາຍຸ
