# LVSP — ສະຖານະວຽກຮັບເອກະສານ / AI

ອັບເດດລ່າສຸດ: Preview ຂຶ້ນ Vercel ແລ້ວ; private Neon storage ທົດສອບຈິງຜ່ານ (ໄຟລ໌ຈຳລອງ), 117 tests ຜ່ານ. Gemini ໃນ Preview ຍັງລໍຖ້າອະນຸຍາດໃຊ້ key. ເບິ່ງ [ບັນທຶກການຂຶ້ນ Preview](VERCEL_PREVIEW_STATUS_20261015.md). ລາຍລະອຽດດ້ານລຸ່ມແມ່ນຜົນກວດກ່ອນເປີດ Neon storage; production ຍັງບໍ່ໄດ້ປ່ຽນ.

## ສ່ວນທີ່ໄດ້ພັດທະນາໃນໂຄງການເດີມ

- ເມນູ “ຮັບເອກະສານ / ກວດຄຳຂໍ” ໃຊ້ login ຂອງ LVSP ເດີມ.
- ເປີດຮ່າງກ່ອນມີ product profile; ແນບ PDF, PNG, JPEG ແລະ UTF-8 TXT.
- ເກັບເອກະສານໃນ private S3 object storage; PostgreSQL ເກັບ metadata/object keys/checksums ເທົ່ານັ້ນ ໂດຍເຊື່ອມ document.document / document.file ທີ່ມີແລ້ວ. ບໍ່ໃຊ້ public web folder ຫຼື ໄຟລ໌ຊົ່ວຄາວຂອງ Vercel ເກັບເອກະສານ.
- ເຈົ້າຂອງຮ່າງ ແລະ system/security administrator ຈຶ່ງເບິ່ງ/ດາວໂຫຼດໄດ້; ຜູ້ກວດຄົນອື່ນຍັງຕ້ອງມີລະບົບມອບໝາຍສິດໃນຂັ້ນຕໍ່ໄປ.
- ກວດຂະໜາດ, ຮູບແບບໄຟລ໌, signature ເບື້ອງຕົ້ນ, SHA-256, ໄຟລ໌ຊ້ຳ ແລະ version ກ່ອນບັນທຶກ.
- ໜ້າກວດທານແບ່ງເອກະສານຕົ້ນສະບັບ/ຂໍ້ມູນຂ້າງກັນ. ຖ້າ browser ບໍ່ສະແດງ PDF ໃນກອບ, ໃຊ້ “ດາວໂຫຼດຕົ້ນສະບັບ”.
- ຕົວເຊື່ອມ Google Gemini ແລະ OpenAI ຝັ່ງ server ຮອງຮັບ content-based document classification, structured fields, ຫຼັກຖານ, ໜ້າ/ຕຳແໜ່ງ ແລະ confidence ທີ່ model ລາຍງານ. ຄ່າ confidence ບໍ່ແມ່ນການຮັບປະກັນຄວາມຖືກຕ້ອງ.
- ຂໍ້ມູນ AI ຈະ pre-fill ຟອມ; ຄ່າທີ່ຂັດກັນບໍ່ຖືກເລືອກໃຫ້ອັດຕະໂນມັດ. ຜູ້ໃຊ້ຕ້ອງກວດ ແລະ ຢືນຢັນ.
- ບັນທຶກການກວດ, ຜູ້ກວດ, ເວລາ, ຄ່າກ່ອນ/ຫຼັງ, audit ແລະ outbox ໃນ transaction. ຮ່າງ REVIEWED ຖືກລັອກ. ຕາຕະລາງໃໝ່ມີ no-hard-delete guards.

## ຂອບເຂດທົດລອງ

ໄຟລ໌ລະ 2 MiB; ຮ່າງລະສູງສຸດ 20 ໄຟລ໌. AI ຮອບນີ້ຈຳກັດ 8 ໄຟລ໌ / ລວມ 8 MiB. Word/Excel ແລະ ໄຟລ໌ຂະໜາດໃຫຍ່ຍັງບໍ່ຮອງຮັບ. Signature checks ບໍ່ແທນ antivirus/content scanning. ຍັງບໍ່ໄດ້ທົດສອບ OCR/ຄວາມແມ່ນຍຳຂອງ AI ກັບ dossier ຈິງ.

“Confirm review” ບັນທຶກເປັນຮ່າງກວດທານ ບໍ່ແມ່ນອະນຸມັດ, ບໍ່ອອກໃບທະບຽນ ແລະ ຍັງບໍ່ສ້າງ product/company ຫຼື regulatory case ອັດຕະໂນມັດ. ການຈັບຄູ່ master, checklist ຈາກກົດລະບຽບ, ການມອບໝາຍຜູ້ກວດ, ການຂໍເອກະສານເພີ່ມ ແລະ Confirm → official structured record ຍັງເປັນວຽກຂັ້ນຕໍ່ໄປ. ບໍ່ໄດ້ສ້າງ Provincial Reporting module ໃໝ່ ຫຼື ປ່ຽນ certificate packaging logic.

## ການເປີດໃຊ້ staging / Vercel

ກ່ອນປ່ຽນ production ຕ້ອງຢືນຢັນ source/deployment ທີ່ໃຊ້ຈິງ, ສຳຮອງ database ແລະ ກວດ pending migrations 000920/000930. Migration 000940 ເປັນການເພີ່ມຕາຕະລາງ; ທົດສອບແລ້ວໃນ database ແຍກ ແຕ່ຍັງບໍ່ລັນໃສ່ Neon production.

ຝັ່ງ server ຕ້ອງມີ NODE_ENV=production, AUTH_MODE=database, LVSP_STORAGE=postgres, DATABASE_URL ແລະ LVSP_AUTH_SECRET ທີ່ປອດໄພ. AI ເປັນທາງເລືອກ: LVSP_AI_PROVIDER=gemini, LVSP_AI_MODEL ທີ່ບັນຊີຮອງຮັບ file/image + structured outputs, ແລະ GEMINI_API_KEY ຝັ່ງ server ເທົ່ານັ້ນ. ຫ້າມໃສ່ key ໃນ frontend ຫຼື public repository.

ປຸ່ມ AI ຈະປິດຈົນກວ່າຕັ້ງຄ່າຄົບ. ຜູ້ໃຊ້ຕ້ອງຢືນຢັນສົ່ງ dossier ນັ້ນໄປ provider ທີ່ລະບຸໃນໜ້າຢືນຢັນ ກ່ອນທຸກການວິເຄາະ. ຄ່າ API ແຍກຈາກ Vercel hosting; store=false ບໍ່ແມ່ນຄຳຮັບປະກັນວ່າ provider ບໍ່ເກັບຂໍ້ມູນໃດໆ. ຕ້ອງຢືນຢັນ data handling/retention ໃຫ້ເໝາະກັບເອກະສານກ່ອນໃຊ້ຈິງ.

## ຜົນກວດ

- Full TypeScript build: ຜ່ານ.
- Isolated regression tests: 116 ລາຍການຜ່ານ.
- Disposable PostgreSQL: 115 migrations ຜ່ານ; ກວດ upload/download, role, owner, UTF-8, stale version, duplicate file, locked draft, audit/outbox, metadata privacy, no-delete/reviewed locks ແລະ upload → mocked AI → human review ຜ່ານ. ບໍ່ມີ official registration write.
- Package validation: 115 migrations / 266 tables ຜ່ານ (PyYAML ບໍ່ມີ, ຈຶ່ງບໍ່ໄດ້ກວດ parse OpenAPI YAML ຜ່ານ Python).
- AI transport ທົດສອບດ້ວຍ mocked response ເທົ່ານັ້ນ; ບໍ່ໄດ້ສົ່ງ dossier ຈິງ ຫຼື ໃຊ້ API ທີ່ເສຍເງິນ.
- UI ຜ່ານ TypeScript build; ຍັງບໍ່ມີ browser visual QA ຂອງໜ້າໃໝ່.
- ຍັງບໍ່ deploy ທັບ Vercel ແລະ ບໍ່ປ່ຽນ production data.

Technical references: [OpenAI file inputs](https://developers.openai.com/api/docs/guides/file-inputs), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses).

Private storage ຕ້ອງຕັ້ງ LVSP_INTAKE_S3_BUCKET, AWS_REGION ແລະ AWS credentials ທີ່ມີສິດ GetObject/PutObject ສະເພາະ prefix lvsp/intake/. ຕ້ອງເປີດ Block Public Access ແລະ ຢືນຢັນ LVSP_INTAKE_S3_PRIVATE_CONFIRMED=true ກ່ອນໃຊ້. ບໍ່ມີການສ້າງ bucket ຫຼື ປ່ຽນ permissions ອັດຕະໂນມັດ. ໄຟລ໌ໃນ test ເກັບໃນ temporary directory ຂອງ disposable cluster ເທົ່ານັ້ນ; production ບໍ່ຮອງຮັບ local file storage. ບໍ່ມີ live S3 ຫຼື live Gemini/OpenAI request ໃນການທົດສອບ.

Object upload ແລະ DB transaction ບໍ່ສາມາດ commit ຮ່ວມກັນໄດ້. ຖ້າ DB commit ລົ້ມເຫຼວຫຼັງ upload ອາດມີ private orphan object; ຕ້ອງມີຂັ້ນຕອນ reconciliation/retention ກ່ອນ production rollout. ລະບົບບໍ່ລຶບເອກະສານອັດຕະໂນມັດ.

## Gemini ເປັນ provider ຫຼັກ — 15 ຕຸລາ 2026

ຜູ້ໃຊ້ເລືອກ Gemini ແລ້ວ. ຖ້າບໍ່ລະບຸ LVSP_AI_PROVIDER ລະບົບຈະເລືອກ Gemini; ຖ້າບໍ່ມີ GEMINI_API_KEY ແລະ LVSP_AI_MODEL ຈະປິດປຸ່ມ AI. ຈະບໍ່ສະຫຼັບໄປ OpenAI ອັດຕະໂນມັດ. OpenAI ຍັງຄົງເປັນຕົວເລືອກທີ່ admin ຕ້ອງຕັ້ງຄ່າເອງ.

ເຂົ້າເວັບ Gemini ດ້ວຍ Gmail ບໍ່ແມ່ນການເຊື່ອມ API ໃຫ້ LVSP. API key ຈັດການໃນ Google AI Studio; ບໍ່ໃຊ້ Gmail password ເປັນ key ແລະ ບໍ່ຕ້ອງຝັງອີເມວບັນຊີໃນ source. ຍັງບໍ່ມີການສ້າງ key, ເຂົ້າບັນຊີ Google, ຕັ້ງ billing ຫຼື ຮຽກ Gemini ຈິງຈາກວຽກນີ້.

ຂັ້ນຕອນສຳລັບ admin: ຈັດການ key ໃນ [Google AI Studio](https://aistudio.google.com/api-keys), ກຳນົດ GEMINI_API_KEY ແລະ model ID ທີ່ບັນຊີຮອງຮັບໃນ server environment ຂອງ staging/Vercel, ກວດ API data handling/quota ຂອງ project ກ່ອນນຳ dossier ຈິງເຂົ້າ, ແລ້ວທົດສອບດ້ວຍເອກະສານຈຳລອງກ່ອນ. ຢ່າສົ່ງ key ໃນແຊັດ ຫຼື commit ລົງ Git.

Google references: [API keys](https://ai.google.dev/gemini-api/docs/api-key), [document inputs](https://ai.google.dev/gemini-api/docs/document-processing), [Generate Content structured output](https://ai.google.dev/gemini-api/docs/generate-content/structured-output).
