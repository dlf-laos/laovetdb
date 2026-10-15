-- ============================================================================
-- LVSP Migration 000900 — TR-2001 Export Application: Guided Service Registration
-- ============================================================================
-- ຈຸດປະສົງ: ລົງທະບຽນ "ຄຳຮ້ອງສົ່ງອອກ" (TR-2001) ເປັນ guided service ໃໝ່
-- ໃນລະບົບ Guided Services ທີ່ມີຢູ່ແລ້ວ (system.service_definition /
-- service_version / service_guide / service_step). ນີ້ແມ່ນຂໍ້ມູນ config
-- ລ້ວນໆ (DATA-ONLY) — ບໍ່ມີ CREATE TABLE / ALTER / DROP.
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-16):
--   * ໃຊ້ຕາຕະລາງ system.service_* ທີ່ມີຢູ່ແລ້ວ, ຄືຮູບແບບດຽວກັບ
--     TR-1007 / TR-1021 / VM-1003 (ຢືນຢັນຄໍລໍາຄົບຖ້ວນ ແລະ ຮູບແບບແຖວຈິງ
--     ຂອງ TR-1007 ຈາກ Round 9 audit, 2026-09-16 — ບໍ່ໄດ້ເດົາ column ໃດເລີຍ).
--   * launch_module_key='export_applications' — ໂຫຼດ module ໃໝ່ໃນ app.ts
--     (ແຍກ patch, ບໍ່ຢູ່ໃນ migration ນີ້).
--   * service_version.status='DRAFT' ຄືກັນກັບ TR-1007/TR-1021/VM-1003
--     (ຮູບແບບປົກກະຕິ — ຍັງບໍ່ແມ່ນ production-signed workflow).
--   * service_guide.status='PILOT' ຄືກັນກັບ TR-1007.
--   * 5 service_step (ບໍ່ແມ່ນ 8 ແບບ TR-1007) — scope ຂອງ milestone ນີ້ຈຳກັດ
--     ພຽງ wizard + submit, ບໍ່ມີ SYSTEM_CHECK/DOCUMENTS/PROCESSING step ຍັງ
--     (ເພີ່ມພາຍຫຼັງໄດ້ໂດຍ service_version ໃໝ່, ບໍ່ແກ້ແຖວນີ້).
--   * step_type/actor_scope ທຸກຄ່າແມ່ນຄ່າທີ່ໃຊ້ຢູ່ແລ້ວໃນລະບົບ (ຢືນຢັນຈາກ
--     Round 8/9 audit): GUIDANCE/FORM/ITEMS/REVIEW/DECLARATION, APPLICANT.
--   * ບໍ່ມີ service_requirement/service_output row ຍັງ (ໃບຢັ້ງຢືນ/ເອກະສານ
--     ປະກອບ ເປັນ milestone ພາຍຫຼັງ).
--   * ໃຊ້ chained writable-CTE ດຽວ (WITH svc/ver/guide ... INSERT INTO
--     service_step) ເພື່ອບໍ່ຕ້ອງໃຊ້ uuid ທີ່ເດົາ — id ຂອງແຖວທີ່ຫາກໍ່ insert
--     ຖືກສົ່ງຕໍ່ໂດຍກົງຜ່ານ RETURNING/SELECT, ບໍ່ມີ hard-coded uuid ໃນໄຟລ໌ນີ້.
--
-- ອ້າງອີງ: claude/LVSP_EXPORT_WIZARD_IMPLEMENTATION_PLAN.md (v2, ອະນຸມັດແລ້ວ)
--          case_no format ອະນຸມັດແລ້ວ: EXP-2026-000001 (internal/system
--          reference number ເທົ່ານັ້ນ, ບໍ່ແມ່ນເລກໃບຢັ້ງຢືນ/ໃບອະນຸຍາດທາງການ —
--          ບໍ່ໄດ້ຖືກ hard-code ຢູ່ບ່ອນໃດໃນ migration ນີ້; ເລກຈິງຖືກອອກຕອນ
--          runtime ຈາກ system.number_sequence, ບໍ່ແມ່ນຈາກ migration).
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction
-- control ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
--
-- ສະຖານະ (2026-09-16): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ຍັງບໍ່ໄດ້ apply ລົງ Neon.
-- ============================================================================

WITH svc AS (
    INSERT INTO system.service_definition
        (service_code, domain_code, name_lo, name_en, description, applicant_type, is_public, is_active)
    VALUES (
        'TR-2001',
        'TR',
        'ຄຳຮ້ອງສົ່ງອອກ',
        'Export Application',
        'Guided wizard to submit an export application: destination country, intended shipment window, and one or more commodity items in a single submission.',
        'COMPANY',
        true,
        true
    )
    RETURNING id
), ver AS (
    INSERT INTO system.service_version
        (service_id, version_no, effective_from, workflow_code, status)
    SELECT id, 1, now(), NULL, 'DRAFT'
    FROM svc
    RETURNING id
), guide AS (
    INSERT INTO system.service_guide
        (service_version_id, category_code, icon, display_order,
         overview_lo, overview_en,
         eligibility_lo, eligibility_en,
         preparation_lo, preparation_en,
         processing_lo, processing_en,
         launch_module_key, launch_action,
         allow_public_browse, requires_authentication,
         configuration_notice_lo, configuration_notice_en,
         status)
    SELECT
        id,
        'TRADE',
        '📦',
        35,
        'ຄຳຮ້ອງສົ່ງອອກ 1 ໃບສາມາດມີຫຼາຍລາຍການສິນຄ້າ. ລະບົບຈະສ້າງເລກອ້າງອີງພາຍໃນ ແລະ ບັນທຶກຄຳຮ້ອງເປັນສະຖານະ SUBMITTED ທັນທີ.',
        'One export application may contain multiple commodity items. LVSP issues an internal reference number and records the application as SUBMITTED immediately.',
        'ກ່ອນຍື່ນ ກວດ Company, ປະເທດປາຍທາງ ແລະ ຂໍ້ມູນສິນຄ້າ (ຊະນິດພັນ/ຈຳນວນ/ຫົວໜ່ວຍ).',
        'Before submission, confirm the company, destination country and item details (species/quantity/unit).',
        'ກະກຽມຂໍ້ມູນບໍລິສັດ, ປະເທດປາຍທາງ, ໄລຍະເວລາຂົນສົ່ງ ແລະ ລາຍການສິນຄ້າ (ສາມາດເພີ່ມໄດ້ຫຼາຍລາຍການ).',
        'Prepare company details, destination country, the intended shipment window and item details (multiple items can be added).',
        'ຫຼັງຍື່ນ, ຄຳຮ້ອງຈະຖືກບັນທຶກເປັນສະຖານະ SUBMITTED ພ້ອມເລກອ້າງອີງພາຍໃນ. ຂັ້ນຕອນ Permit/Shipment/Health Certificate/e-Cert ຈະເພີ່ມພາຍຫຼັງໃນ milestone ຕໍ່ໄປ.',
        'After submission, the application is recorded as SUBMITTED with an internal reference number. Permit/Shipment/Health Certificate/e-Cert steps are added in a later milestone.',
        'export_applications',
        'CREATE',
        true,
        true,
        'ຂໍ້ກຳນົດ/ຂັ້ນຕອນໃນໜ້ານີ້ແມ່ນ configuration ສຳລັບ Staging/Pilot (wizard + submit ເທົ່ານັ້ນ). Permit/Shipment/Health Certificate/e-Cert ຍັງບໍ່ໄດ້ຮວມຢູ່ milestone ນີ້.',
        'Requirements/steps shown here are staging/pilot configuration (wizard + submit only). Permit/Shipment/Health Certificate/e-Cert are not part of this milestone.',
        'PILOT'
    FROM ver
    RETURNING id
)
INSERT INTO system.service_step
    (service_version_id, step_code, sequence_no, name_lo, name_en, description_lo, description_en, step_type, actor_scope, is_required, configuration, status)
SELECT
    ver.id, x.step_code, x.sequence_no, x.name_lo, x.name_en, x.description_lo, x.description_en, x.step_type, 'APPLICANT', true, '{}'::jsonb, 'ACTIVE'
FROM ver
CROSS JOIN guide
CROSS JOIN (VALUES
    ('BEFORE_START',       10, 'ກວດຄວາມພ້ອມ',        'Before you start',
        'ກວດ Company ແລະ ຂໍ້ມູນປະເທດປາຍທາງກ່ອນເລີ່ມ.',
        'Confirm company details and destination country before starting.',
        'GUIDANCE'),
    ('APPLICATION_HEADER', 20, 'ຂໍ້ມູນຄຳຮ້ອງ',        'Application header',
        'ເລືອກ Company, ປະເພດບໍລິການ, ປະເທດປາຍທາງ ແລະ ໄລຍະເວລາຂົນສົ່ງ.',
        'Select company, work area, destination country and the intended shipment window.',
        'FORM'),
    ('ITEMS',              30, 'ລາຍການສິນຄ້າ',        'Items',
        'ເພີ່ມລາຍການສິນຄ້າ (ຊະນິດພັນ/ຈຳນວນ/ຫົວໜ່ວຍ) — ສາມາດເພີ່ມໄດ້ຫຼາຍລາຍການ.',
        'Add commodity items (species/quantity/unit) — multiple items may be added.',
        'ITEMS'),
    ('REVIEW',             40, 'ກວດທານກ່ອນສົ່ງ',       'Review',
        'ກວດຂໍ້ມູນຄຳຮ້ອງ ແລະ ລາຍການທັງໝົດກ່ອນຍື່ນ.',
        'Review the application and all items before submission.',
        'REVIEW'),
    ('SUBMIT',             50, 'ຢືນຢັນ ແລະ ສົ່ງຄຳຮ້ອງ', 'Confirm and submit',
        'ຢືນຢັນ ແລະ ສົ່ງຄຳຮ້ອງ — ລະບົບຈະອອກເລກອ້າງອີງພາຍໃນທັນທີ.',
        'Confirm and submit — the system issues an internal reference number immediately.',
        'DECLARATION')
) AS x(step_code, sequence_no, name_lo, name_en, description_lo, description_en, step_type);

-- ============================================================================
-- END 000900 — 0 CREATE TABLE, 0 ALTER, 0 DROP, 1 service_definition,
-- 1 service_version, 1 service_guide, 5 service_step. DATA-ONLY.
-- ============================================================================
