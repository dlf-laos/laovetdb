# ການອັບເດດ LVSP — 16 ຕຸລາ 2026

Source ໃໝ່ແມ່ນ TypeScript monorepo ທີ່ສືບຕໍ່ LVSP ເດີມ. ບໍ່ແມ່ນ demo ແຍກ. Vercel build ນຳ `apps/web/public` ໄປເປັນໜ້າເວັບ ແລະ `api/index.js` ເປັນ API.

## ເປັນຫຍັງຍັງເຫັນອັນເກົ່າ

- `lvsp-laos.vercel.app` ຍັງຊີ້ໄປ production ວັນທີ 7 ຕຸລາ; ຍັງບໍ່ໄດ້ promote Source ໃໝ່.
- GitHub main ຍັງມີ `index.html` ເກົ່າອັນດຽວ. ການບັນທຶກ API key ບໍ່ໄດ້ອັບເດດ Source Code ຫຼື UI.
- Preview ໃໝ່ໃຊ້ຖານຂໍ້ມູນທົດສອບແຍກ; ບໍ່ຄວນ promote ພ້ອມຄ່າ database ທົດສອບໄປເປັນລະບົບງານຈິງ.
- `DNS_PROBE_FINISHED_NXDOMAIN` ແມ່ນບັນຫາຄົ້ນຫາຊື່ເວັບ; ບໍ່ໄດ້ຊີ້ວ່າ UI ຜິດ. Google DNS ຄົ້ນພົບ hostname ແຕ່ເຄືອຂ່າຍເຄື່ອງນີ້ຍັງເຊື່ອມ HTTPS ໄປ Vercel app ບໍ່ສຳເລັດ.

## ທາງເຂົ້າໃໝ່

- `/admin.html` ເປີດ Admin Center ຂອງ LVSP ໃໝ່; ຕ້ອງ login ແລະ ມີສິດ admin ເດີມ.
- `/?module=document_intake` ເປີດຮັບເອກະສານ/ກວດທານ.
- ລິ້ງ module ຖືກຮັກສາຫຼັງ login ແລະ ການປ່ຽນ temporary password.
- ທ້າຍໜ້າສະແດງ `Dossier Intake & Review · 20261016` ເພື່ອຈຳແນກ Source ໃໝ່.

## AI ທີ່ໃຊ້

`LVSP_AI_PROVIDER=gemini` ໃນ Preview. ຕົວເລືອກປົກກະຕິໃນ Source ແມ່ນ Gemini. OpenAI adapter ເປັນທາງເລືອກທີ່ຈະບໍ່ຖືກເອີ້ນ ຖ້າບໍ່ມີການປ່ຽນ provider ໂດຍຈົງໃຈ. ບໍ່ມີ fallback ໄປ OpenAI.

ການເຊື່ອມ ChatGPT/Codex ກັບ Vercel/GitHub/Neon ເປັນສິດເຄື່ອງມືພັດທະນາ; ບໍ່ແມ່ນການເລືອກ model ວິເຄາະ dossier ໃນ LVSP.

Gemini key ທີ່ບັນທຶກໄວ້ຍັງມີສະເພາະ Production. ການໃຫ້ Preview ໃຊ້ key ນີ້ຍັງລໍຖ້າຄຳຢືນຢັນຈາກເຈົ້າຂອງ. ຍັງຕ້ອງກຳນົດ model ແລະ ທົດສອບການເອີ້ນ Gemini ຈິງ. AI ຍັງບໍ່ພ້ອມໃຊ້ໃນ Preview.

## ກ່ອນປ່ຽນເວັບຫຼັກ

1. ກວດ Preview ໃນ browser: login, Admin Center, ແນບ/ເປີດເອກະສານ ແລະ ວຽກເດີມ.
2. ສຳຮອງຖານຂໍ້ມູນງານຈິງ; ກວດວ່າມີຂໍ້ມູນໃນ browser storage ຂອງເວັບເກົ່າທີ່ຕ້ອງ export ຫຼືບໍ່.
3. ກວດ migrations ທີ່ຍັງບໍ່ apply ແລະ ກຳນົດ Production environment ໃຫ້ຖືກຖານຂໍ້ມູນ/ບ່ອນເກັບເອກະສານ.
4. ຂຶ້ນ Source ໃໝ່ໃນ GitHub ແລະ ເຊື່ອມ Vercel ກັບ repository ເພື່ອ deploy ອັດຕະໂນມັດ.
5. ເມື່ອກວດຜ່ານ ຈຶ່ງ deploy/promote Production ແລະ ກວດລິ້ງຫຼັກອີກຄັ້ງ. ເກັບ deployment ເກົ່າໄວ້ສຳລັບ rollback.
