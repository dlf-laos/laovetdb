-- ============================================================================
-- LVSP Migration 000910 — Vet Drug: Combined Packaging Mode + Herbal Category + AMR/WOAH classification
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມ 3 ຄວາມສາມາດໃໝ່ໃສ່ Veterinary Drug Registration ແບບ ADDITIVE
-- ລ້ວນໆ (ບໍ່ແກ້/ບໍ່ລຶບຄໍລຳເກົ່າ, ບໍ່ກະທົບ 26 ແຖວທະບຽນຢາທີ່ມີຢູ່ແລ້ວ):
--   1. size_mode ('single'/'combined'/'multi') ໃສ່ product.product_regulatory_profile
--      — NULL ສຳລັບ 26 ແຖວເກົ່າ (ຖືວ່າ "legacy", app code fallback ໄປໃຊ້
--      ພຶດຕິກຳ total>1 ເກົ່າ), ບັງຄັບເລືອກສະເພາະແຖວໃໝ່ (ບັງຄັບຢູ່ໃນ code, ບໍ່ແມ່ນ
--      NOT NULL constraint — ອະນຸມັດໂດຍ Lee 2026-09-22).
--   2. am_class / am_importance / am_growth_promoter (AMR/WOAH classification,
--      am_importance ຈຳກັດ 3 ຄ່າ VCIA/VHIA/VIA) ໃສ່ product_regulatory_profile
--      — ທັງໝົດ nullable, ໃຊ້ສະເພາະເມື່ອ category = ANTIMICROBIAL (ບັງຄັບຢູ່ໃນ
--      frontend, ບໍ່ແມ່ນ DB constraint, ຄືຮູບແບບດຽວກັບ ATCvet-by-category ທີ່ມີແລ້ວ).
--   3. product.product_common_composition (ຕາຕະລາງໃໝ່) — ສູດປະສົມຮ່ວມກັນ 1 ອັນ
--      ຕໍ່ product ສຳລັບ "combined" mode (ຫຼາຍຂະໜາດບັນຈຸ ໃຊ້ສູດດຽວກັນ) — mirrors
--      product.package_composition's columns ແຕ່ຜູກກັບ product_id ໂດຍກົງ
--      (ບໍ່ຜູກກັບ package_version_id) ເພາະ combined mode ບໍ່ມີສູດແຍກຕໍ່ package.
--   4. 1 ແຖວອ້າງອີງໃໝ່ໃສ່ lookup.veterinary_drug_reference_term: ໝວດ Herbal /
--      Traditional Medicine (domain_code='CATEGORY', code='HERBAL_TRADITIONAL').
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-22 + ຢືນຢັນ code ຈິງ Round 6/7/8,
-- 2026-09-28 — ບໍ່ໄດ້ເດົາ column/ຕາຕະລາງໃດເລີຍ, ທຸກຄ່າອີງ audit ຈິງ):
--   * source_system/source_reference ຂອງແຖວ Herbal ໃໝ່ ໃຊ້ຄ່າດຽວກັບແຖວ CATEGORY
--     ອື່ນທີ່ມີຢູ່ແລ້ວ ('LVSP_LEGACY'/'admin(4) controlled vocabulary') — ແກ້ໄຂຈາກ
--     ຄ່າທີ່ຮ່າງໄວ້ກ່ອນໜ້ານີ້ໃນ SQL Code Review doc (ພົບຄວາມບໍ່ຕົງກັນ Round 6).
--   * sort_order ຄິດໄລ່ອັດຕະໂນມັດ (MAX+1 ພາຍໃນ domain_code='CATEGORY') ແທນຄ່າ
--     hard-code — ບໍ່ຮູ້ຄ່າ sort_order ປັດຈຸບັນຂອງ 8 ໝວດທີ່ມີຢູ່ແລ້ວແທ້ 100%.
--   * product_common_composition.product_id ອ້າງອີງ product.product(id) ດ້ວຍ
--     ຮູບແບບດຽວກັບ product.package.product_id ທີ່ມີຢູ່ແລ້ວ (ຢືນຢັນຈາກ code ຈິງ
--     ໃນ postgres-store.ts: `select * from product.package where product_id=$1`).
--   * ທຸກ ALTER/CREATE ໃຊ້ IF NOT EXISTS — ປອດໄພຮັນຊ້ຳໄດ້ (ຄືກັບ DRYRUN pattern
--     ຂອງທຸກ migration ກ່ອນໜ້ານີ້ໃນໂຄງການນີ້).
--   * ບໍ່ມີ DROP/RENAME/DELETE ຢູ່ບ່ອນໃດເລີຍໃນໄຟລ໌ນີ້.
--
-- ອ້າງອີງ: claude/LVSP_VETDRUG_COMBINED_HERBAL_IMPLEMENTATION_PLAN.md (ອະນຸມັດແລ້ວ),
--          claude/LVSP_VETDRUG_COMBINED_HERBAL_SQL_CODE_REVIEW.md (ອະນຸມັດແລ້ວ,
--          ຍົກເວັ້ນ source_system/source_reference ທີ່ແກ້ໄຂໃນໄຟລ໌ນີ້).
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction control
-- ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
--
-- ສະຖານະ (2026-09-28): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ຍັງບໍ່ໄດ້ apply ລົງ Neon. ໜ້າ UI/code patch (app.ts) ຍັງແຍກຕ່າງຫາກ, ຍັງບໍ່ຂຽນ.
-- ============================================================================

-- 1) size_mode + AMR/WOAH classification columns on product.product_regulatory_profile
ALTER TABLE product.product_regulatory_profile
    ADD COLUMN IF NOT EXISTS size_mode text,
    ADD COLUMN IF NOT EXISTS am_class text,
    ADD COLUMN IF NOT EXISTS am_importance text,
    ADD COLUMN IF NOT EXISTS am_growth_promoter boolean;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'product_regulatory_profile_am_importance_check'
    ) THEN
        ALTER TABLE product.product_regulatory_profile
            ADD CONSTRAINT product_regulatory_profile_am_importance_check
            CHECK (am_importance IN ('VCIA','VHIA','VIA') OR am_importance IS NULL);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'product_regulatory_profile_size_mode_check'
    ) THEN
        ALTER TABLE product.product_regulatory_profile
            ADD CONSTRAINT product_regulatory_profile_size_mode_check
            CHECK (size_mode IN ('single','combined','multi') OR size_mode IS NULL);
    END IF;
END $$;

-- 2) New table: shared/common composition for "combined" packaging mode
--    (mirrors product.package_composition's columns, FK to product_id instead
--    of package_version_id, since combined mode has ONE formula shared by all
--    pack sizes rather than a per-package formula).
CREATE TABLE IF NOT EXISTS product.product_common_composition (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id        uuid NOT NULL REFERENCES product.product(id),
    sequence_no       integer NOT NULL,
    ingredient_name   text NOT NULL,
    ingredient_role   character varying NOT NULL,
    quantity_text     text,
    unit_text         text,
    part_text         text,
    equivalence_text  text,
    created_at        timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_common_composition_product_id
    ON product.product_common_composition(product_id);

-- 3) New reference-vocabulary row: Herbal / Traditional Medicine category
--    (idempotent — safe to re-run; sort_order computed, not hard-coded;
--    source_system/source_reference match the real existing convention).
INSERT INTO lookup.veterinary_drug_reference_term
    (domain_code, code, value_text, name_lo, name_en, sort_order,
     source_system, source_reference, is_active)
SELECT
    'CATEGORY',
    'HERBAL_TRADITIONAL',
    'ຢາສະໝຸນໄພ / ຢາພື້ນເມືອງ (Herbal / Traditional Medicine)',
    'ຢາສະໝຸນໄພ / ຢາພື້ນເມືອງ (Herbal / Traditional Medicine)',
    'Herbal / Traditional Medicine',
    (SELECT COALESCE(MAX(sort_order), 0) + 1
       FROM lookup.veterinary_drug_reference_term
      WHERE domain_code = 'CATEGORY'),
    'LVSP_LEGACY',
    'admin(4) controlled vocabulary',
    true
WHERE NOT EXISTS (
    SELECT 1 FROM lookup.veterinary_drug_reference_term
     WHERE domain_code = 'CATEGORY' AND code = 'HERBAL_TRADITIONAL'
);

-- ============================================================================
-- END 000910 — 0 DROP, 0 RENAME, 0 DELETE. 4 ADD COLUMN (nullable) +
-- 2 CHECK CONSTRAINT (guarded) + 1 CREATE TABLE (new) + 1 CREATE INDEX (new) +
-- 1 INSERT (guarded, idempotent) ໃສ່ reference table. 26 ແຖວທະບຽນຢາເກົ່າ ບໍ່ຖືກແຕະ.
-- ============================================================================
