# LVSP v0.4.0 — Priority Veterinary Products Pack

ຊຸດນີ້ສຸມໃສ່ວຽກທີ່ຕ້ອງໃຊ້ກ່ອນ:

1. ທະບຽນຢາສັດ
2. ອຸປະກອນສັດຕະວະແພດ
3. ແຜນນຳເຂົ້າປະຈຳປີ
4. ຄຳຮ້ອງນຳເຂົ້າແຕ່ລະຄັ້ງ
5. ລາຍການ mixed items: ຢາ + ວັກຊີນ + ຊີວະພັນ + ອຸປະກອນ + diagnostic kits ຢູ່ໃນແຜນ/ຄຳຮ້ອງດຽວ.

## Locked business rule

- 1 Annual Import Plan ສາມາດມີຫຼາຍ item types ປົນກັນ.
- 1 Import Application ສາມາດມີຫຼາຍ item types ປົນກັນ.
- ບໍ່ແຍກຄຳຮ້ອງຢາ ແລະ ຄຳຮ້ອງອຸປະກອນ.
- ການກວດ regulatory eligibility ເຮັດໃນລະດັບ item.
- Medicine/Vaccine/Biological: ກວດ registration status + expiry.
- Veterinary device: ກວດ authorization status; ຖ້າຍັງບໍ່ active ໃຫ້ REVIEW_REQUIRED.

## Source references used

UI/business logic was adapted from the user's `admin(5).html` and `index(1).html`. The old IndexedDB/localStorage provider was not copied into LVSP. Browser → LVSP API → Neon PostgreSQL remains the authoritative architecture.
