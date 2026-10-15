# LVSP v0.8 — Company Master + Multi-Site / Multi-Address

## ຫຼັກການ

- 1 ນິຕິບຸກຄົນ = 1 Company Master ID.
- ບໍລິສັດດຽວສາມາດມີຫຼາຍ Site/Facility: ທີ່ຢູ່ຈົດທະບຽນ, ສຳນັກງານໃຫຍ່, ສຳນັກງານຜູ້ຖືທະບຽນ, ສຳນັກງານຜູ້ນຳເຂົ້າ, ໂຮງງານຜະລິດ, ສາງ, ສາຂາ, ສະຖານທີ່ຈັດຈຳໜ່າຍ.
- Company Role ແລະ Site Role ແຍກກັນ. ບໍລິສັດດຽວອາດເປັນ Manufacturer + Importer + Distributor + Registration Holder ໄດ້.
- Product Registration ອ້າງອີງທັງ Company ແລະ Site ຕາມບົດບາດ.
- Annual Plan / Import Application ເລືອກ Company Master ແລະ Site ທີ່ຍື່ນເອກະສານ.
- ການແກ້ໄຂຂໍ້ມູນ Master ມີ audit; ຂໍ້ມູນກົດລະບຽບ/ໃບທີ່ອອກແລ້ວຕ້ອງຮັກສາ snapshot ຕາມເວລາ.
- Legacy duplicates ບໍ່ merge ອັດຕະໂນມັດ. LVSP ສະແດງ candidate ໃຫ້ພະນັກງານ review.

## ເວລາສ້າງ Company Master

ຖ້າບໍລິສັດຮູ້ຈັກຢູ່ແລ້ວ ໃຫ້ສ້າງ/ກວດ Company Master ກ່ອນ. ຖ້າເປັນບໍລິສັດໃໝ່ທີ່ພົບໃນຄຳຮ້ອງຄັ້ງທຳອິດ ໃຫ້ສ້າງ Company Master ຄັ້ງດຽວ, ເພີ່ມ Site/Address ທີ່ກ່ຽວຂ້ອງ ແລ້ວໃຫ້ຄຳຮ້ອງເລືອກຈາກ Master.

## ຂໍ້ມູນຫຼັກ

Company: legal names, enterprise/business number, tax number, country, registration date, general contacts, status, aliases, roles.

Site/Facility: role, facility/site number, Lao/English name, Lao/English address, contacts, primary flag, valid-from/to, status, notes.

External Registration/Licence: type, number, related site (optional), issuing authority, issue/expiry, status.
