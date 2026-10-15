# LVSP v0.9 — Guided Digital Services & Workflow UX

## ຈຸດປະສົງ

v0.9 ເພີ່ມຊັ້ນ UX ທີ່ຂາດຈາກ Blueprint: ຜູ້ໃຊ້ບໍ່ຄວນເຫັນແຕ່ຕາຕະລາງ/CRUD, ແຕ່ຄວນສາມາດເລືອກ “ຂ້ອຍຕ້ອງການເຮັດຫຍັງ?” ແລ້ວ LVSP ພາເດີນທີລະຂັ້ນ.

ສະຖາປັດຕະຍະກຳ Core, Neon PostgreSQL, existing Drug/Trade/Company modules ແລະ legacy data ຍັງເປັນຖານເດີມ. v0.9 ບໍ່ restart ໂຄງການ.

## 3 ຊັ້ນຂອງ UX

1. **Public Service Catalog** — ເບິ່ງບໍລິການ, ຜູ້ມີສິດ, ສິ່ງທີ່ຕ້ອງກະກຽມ, steps ແລະ output ໂດຍບໍ່ login.
2. **Applicant Guided Journey** — login ແລ້ວ Start Draft, Save/Continue, checklist, step-by-step preparation ແລະ link ໄປ detailed domain form.
3. **My Work / Staff Queue** — task-centric view ສຳລັບ workflow task, domain queue ແລະ guided drafts.

## Configuration-driven

ຂໍ້ມູນຄູ່ມືບໍລິການບໍ່ hard-code ທຸກຢ່າງໃນ UI. Neon ເກັບ versioned configuration ໃນ:

- `system.service_definition`
- `system.service_version`
- `system.service_guide`
- `system.service_step`
- `system.service_requirement`
- `system.service_output`

Draft runtime ຢູ່:

- `casework.service_draft`
- `casework.service_draft_step`
- `casework.service_draft_requirement`

ເມື່ອ user ສ້າງ detailed record ແລ້ວ, guided draft ຈະ link ກັບ target resource/target ID ເພື່ອຮັກສາ traceability.

## Priority Pilot Services

v0.9 ເລີ່ມດ້ວຍ 3 ບໍລິການທີ່ user ກຳລັງໃຊ້ຈິງ:

- `VM-1003` Veterinary Product Registration
- `TR-1021` Annual Veterinary Products Import Plan
- `TR-1007` Veterinary Products Import Application

Trade services ຮັກສາ business rule ທີ່ຢືນຢັນແລ້ວ: ແຜນ/ຄຳຮ້ອງ 1 ໃບສາມາດມີ medicine/vaccine/biological/device ປົນກັນ ແລະຮອງຮັບ Excel bulk import.

## Legal/Regulatory Boundary

Requirements ໃນ v0.9 ແມ່ນ **Staging/Pilot configuration**. ກ່ອນ Production ຕ້ອງກວດຢືນຢັນ legal instruments, SOP, approval authority, required documents, fee, SLA ແລະ output template ທາງການ. Architecture ຮອງຮັບ versioning ເພື່ອປ່ຽນ rule ໃນອະນາຄົດໂດຍບໍ່ຮື້ລະບົບ.

## Scope Boundary of v0.9

v0.9 ບໍ່ໄດ້ອ້າງວ່າ Applicant Portal/Staff Portal Production-ready ແລ້ວ. ຍັງຕ້ອງມີ official OIDC/SSO, organization/role assignment, object storage, notification provider, e-signature/PKI, official external integrations, UAT, security review ແລະ deployment hardening.

## Next Expansion Pattern

ເມື່ອມີແບບຟອມ/ເອກະສານຈິງຂອງ DLF ສຳລັບ service ໃດ:

`Real document/SOP → field/rule analysis → service version → requirements → guided steps → workflow → detailed form → output template → reports/integration`.

ຫຼັກການນີ້ໃຫ້ໃຊ້ກັບ Feed, Animal Trade, Facility, Inspection, Laboratory, Farm/Animal Movement, Disease, Fisheries, GIS/Analytics ແລະ services ອື່ນໆຕໍ່ໄປ.
