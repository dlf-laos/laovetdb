# LVSP v0.7 — admin(4) Interaction & Print Fidelity

ເປົ້າໝາຍ: ນຳ interaction ສຳຄັນຈາກ admin(4).html ເຂົ້າ LVSP API + Neon ໂດຍບໍ່ກັບໄປໃຊ້ browser-only database.

## ທະບຽນຢາ
- ກົດແຖວລາຍການ → ເປີດ Detail.
- Detail ສະແດງ Product/Clinical/Company/Regulatory/Packaging/Composition.
- ແຕ່ລະ Presentation ມີປຸ່ມພິມໃບທະບຽນ.
- ຖ້າມີຫຼາຍ Presentation → Print All: 1 presentation = 1 A4 page.
- ມີ ໃບກິດສຳພັນ.
- ມີ Edit; ການແກ້ packaging ສ້າງ package_version ໃໝ່ ແລະຮັກສາ history.

## Trade
- ກົດ Import Application → ເບິ່ງ header + mixed items.
- ພິມ Notification Letter / Import Permit.
- ກົດ Annual Plan → ເບິ່ງ items ທັງໝົດ.

## ANIMUSE / AMR
- ເພີ່ມເມນູ summary ຈາກ Neon import history.

## Data safety
- Patch v0.7 ບໍ່ມີ destructive database migration.
- `.env.neon` ບໍ່ຖືກປ່ຽນ.
- Existing Neon data ບໍ່ຖືກລຶບ.
