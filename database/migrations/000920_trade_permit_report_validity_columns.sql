-- ============================================================================
-- LVSP Migration 000920 — Trade Permit Report View: add validity/expiry columns
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມ 2 ຄໍລຳໃໝ່ (valid_from, permit_valid_to) ໃສ່ VIEW
-- analytics.v_veterinary_trade_permit_report ແບບ ADDITIVE ລ້ວນໆ — CREATE OR
-- REPLACE VIEW ໂດຍຄໍລຳເກົ່າທັງໝົດ (21 ຄໍລຳ) ຄົງຢູ່ຄືເກົ່າ 100% ທັງລຳດັບ ແລະ
-- ຊື່ (ຢືນຢັນຈາກ pg_get_viewdef ຈິງ, Round 15, 2026-09-28), ພຽງແຕ່ເພີ່ມ 2
-- ຄໍລຳໃໝ່ຕໍ່ທ້າຍ. ບໍ່ແຕະຕາຕະລາງ trade.import_application ຫຼື
-- trade.import_application_item ເລີຍ — VIEW ອ່ານຄໍລຳ valid_from/permit_valid_to
-- ທີ່ມີຢູ່ແລ້ວໃນ trade.import_application (ຢືນຢັນຈາກ code ຈິງ, Round 10) ເຂົ້າມາ
-- ສະແດງເທົ່ານັ້ນ — ບໍ່ມີ column ໃໝ່ໃນຕາຕະລາງໃດເລີຍ.
--
-- ເຫດຜົນ: ໜ້າ Trade workspace (renderTradeLegacyWorkspace → permitsTab, ໃນ
-- apps/web/src/legacy-workspaces-v16.ts) ດຶງຂໍ້ມູນຈາກ backend endpoint
-- /legacy-parity/reports/trade ເຊິ່ງຮັນ
-- `select * from analytics.v_veterinary_trade_permit_report`
-- (ຢືນຢັນຈາກ apps/api/src/core/legacy-parity.ts, Round 14) — ດັ່ງນັ້ນເພີ່ມ
-- ຄໍລຳໃສ່ VIEW ນີ້ຄືວິທີດຽວທີ່ຕ້ອງແກ້ຝັ່ງ database, ບໍ່ຕ້ອງແກ້ backend code ເລີຍ
-- (select * ຈະດຶງຄໍລຳໃໝ່ອັດຕະໂນມັດ, ແລ້ວ camelCase key conversion ຂອງ API layer
-- ຈະສົ່ງອອກເປັນ validFrom/permitValidTo ໃຫ້ frontend ໂດຍອັດຕະໂນມັດ).
--
-- ອະນຸມັດ: Lee ເລືອກ "ໜ້າຕິດຕາມອາຍຸໃບ" ເປັນລຳດັບ 1 ໃນ 4 ຈຸດ (2026-09-28), ອີງ
-- Round 10-15 ຂອງ audit ຊຸດ LVSP_IMPORTEXPORT_AUDIT (ບໍ່ໄດ້ເດົາ column ໃດເລີຍ —
-- Round 15 ຢືນຢັນ view ປັດຈຸບັນມີ 21 ຄໍລຳ, ບໍ່ມີ valid_from/permit_valid_to,
-- ອ່ານ pg_get_viewdef ຈິງ).
--
-- ໝາຍເຫດ: ບໍ່ມີ DROP/RENAME/DELETE ຢູ່ບ່ອນໃດເລີຍ. CREATE OR REPLACE VIEW
-- ປອດໄພຮັນຊ້ຳໄດ້ (idempotent) ເພາະ query ດຽວກັນທຸກຄັ້ງ. ບໍ່ມີ BEGIN/COMMIT
-- ຂອງຕົນເອງ — transaction control ຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps
-- ໃນ BEGIN...ROLLBACK, scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວ
-- ຕອນ apply ຈິງ) — ຄືຮູບແບບດຽວກັບ migration 000910.
--
-- ສະຖານະ (2026-09-28): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ============================================================================

CREATE OR REPLACE VIEW analytics.v_veterinary_trade_permit_report AS
 SELECT ia.id AS application_id,
    ia.application_no,
    ia.permit_no,
    ia.import_type AS movement_type,
    ia.application_date,
    ia.decision_date,
    ia.cleared_date,
    COALESCE(c.legal_name_lo, c.legal_name_en) AS operator_name,
    ia.origin_country,
    ia.destination_country,
    ia.border_checkpoint,
    ia.checkpoint_out,
    ia.transport_mode,
    count(i.id)::integer AS item_count,
    COALESCE(sum(i.requested_quantity), 0::numeric) AS requested_quantity,
    COALESCE(sum(COALESCE(i.cleared_packs, i.cleared_quantity, 0::numeric)), 0::numeric) AS total_packs,
    COALESCE(sum(i.item_value), 0::numeric) AS total_value,
    COALESCE(sum(i.active_substance_kg), 0::numeric) AS amr_kg,
    ia.status,
    ia.created_at,
    ia.updated_at,
    ia.valid_from,
    ia.permit_valid_to
   FROM trade.import_application ia
     LEFT JOIN master.company c ON c.party_id = ia.company_id
     LEFT JOIN trade.import_application_item i ON i.application_id = ia.id
  GROUP BY ia.id, ia.application_no, ia.permit_no, ia.import_type, ia.application_date, ia.decision_date, ia.cleared_date, c.legal_name_lo, c.legal_name_en, ia.origin_country, ia.destination_country, ia.border_checkpoint, ia.checkpoint_out, ia.transport_mode, ia.status, ia.created_at, ia.updated_at, ia.valid_from, ia.permit_valid_to;

-- ============================================================================
-- END 000920 — 0 DROP, 0 RENAME, 0 DELETE. 1 CREATE OR REPLACE VIEW
-- (21 ຄໍລຳເກົ່າ ຄົງຄືເກົ່າ 100% + 2 ຄໍລຳໃໝ່ຕໍ່ທ້າຍ = 23 ຄໍລຳ). ບໍ່ແຕະຕາຕະລາງໃດເລີຍ.
-- ============================================================================
