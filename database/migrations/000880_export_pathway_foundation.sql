-- ============================================================================
-- LVSP Migration 000880 — Export Pathway Foundation
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມໂຄງສ້າງຂໍ້ມູນຂັ້ນຕ່ຳສຸດເພື່ອຮອງຮັບ "ການລົງທະບຽນເສັ້ນທາງສົ່ງອອກ"
-- (Export Pathway Registration) — ຂັ້ນຕອນທີ 1 ຂອງ 3
-- (Export Pathway -> e-Cert Integration -> LNSW/Single Window Integration).
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-11):
--   * ບໍ່ສ້າງ trade.export_application ເປັນ header table ໃໝ່.
--     ໃຊ້ casework.application (ຜ່ານ casework.regulatory_case) ເປັນ header ແທນ.
--   * ໃຊ້ຄືນ: trade.permit, trade.shipment, trade.health_certificate,
--     document.certificate, certification.*, governance.*,
--     trade.annual_plan_service_type (ລະບົບ annual-plan ທີ່ມີຢູ່ແລ້ວ),
--     casework.service_draft (wizard autosave, ບໍ່ສ້າງ draft table ໃໝ່).
--   * ພຽງ 2 ຕາຕະລາງເພີ່ມເຕີມ (additive-only — ບໍ່ມີ ALTER/DROP ຂອງເກົ່າ):
--       trade.export_application_detail  (1:1 ກັບ casework.application)
--       trade.export_application_item    (1:N ກັບ casework.application)
--   * HS/AHTN code = free text (ບໍ່ພົບ lookup ຕາຕະລາງສະເພາະໃນ schema ປັດຈຸບັນ).
--   * species_id / unit_id ອ້າງອີງ lookup.species(id) / lookup.unit_of_measure(id)
--     (id = uuid PK ຈິງ, ຢືນຢັນຈາກ LVSP_000880_LOOKUP_VERIFY.sh, 2026-09-11).
--
-- ອ້າງອີງ: claude/LVSP_000880_FINAL_IMPLEMENTATION_SPEC.md (ອະນຸມັດແລ້ວ)
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction control
-- ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. trade.export_application_detail
--    1:1 extension ຂອງ casework.application ສະເພາະຂໍ້ມູນສົ່ງອອກ
-- ----------------------------------------------------------------------------
CREATE TABLE trade.export_application_detail (
    id                        uuid        NOT NULL DEFAULT gen_random_uuid(),
    application_id            uuid        NOT NULL,
    service_type              varchar     NOT NULL,
    destination_country_id    uuid        NULL,
    intended_shipment_from    date        NULL,
    intended_shipment_to      date        NULL,
    notes                     text        NULL,
    created_at                timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT export_application_detail_pkey
        PRIMARY KEY (id),

    CONSTRAINT export_application_detail_application_id_key
        UNIQUE (application_id),

    CONSTRAINT export_application_detail_application_id_fkey
        FOREIGN KEY (application_id)
        REFERENCES casework.application (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_service_type_fkey
        FOREIGN KEY (service_type)
        REFERENCES trade.annual_plan_service_type (service_type)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_destination_country_id_fkey
        FOREIGN KEY (destination_country_id)
        REFERENCES lookup.country (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_shipment_dates_chk
        CHECK (
            intended_shipment_from IS NULL
            OR intended_shipment_to IS NULL
            OR intended_shipment_from <= intended_shipment_to
        )
);

COMMENT ON TABLE trade.export_application_detail IS
    'LVSP 000880: export-specific 1:1 extension of casework.application (export pathway registration, step 1 of 3). Header record stays casework.application/regulatory_case.';

-- ----------------------------------------------------------------------------
-- 2. trade.export_application_item
--    1:N line items (ສິນຄ້າ) ຂອງ application ສົ່ງອອກໜຶ່ງໃບ
-- ----------------------------------------------------------------------------
CREATE TABLE trade.export_application_item (
    id                 uuid        NOT NULL DEFAULT gen_random_uuid(),
    application_id     uuid        NOT NULL,
    item_no            int         NOT NULL,
    commodity_class    varchar     NULL,
    species_id         uuid        NULL,
    product_id         uuid        NULL,
    item_description   text        NULL,
    hs_ahtn_code       varchar     NULL,
    quantity           numeric     NULL,
    unit_id            uuid        NULL,
    notes              text        NULL,

    CONSTRAINT export_application_item_pkey
        PRIMARY KEY (id),

    CONSTRAINT export_application_item_app_item_no_key
        UNIQUE (application_id, item_no),

    CONSTRAINT export_application_item_application_id_fkey
        FOREIGN KEY (application_id)
        REFERENCES casework.application (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_species_id_fkey
        FOREIGN KEY (species_id)
        REFERENCES lookup.species (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_product_id_fkey
        FOREIGN KEY (product_id)
        REFERENCES product.product (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_unit_id_fkey
        FOREIGN KEY (unit_id)
        REFERENCES lookup.unit_of_measure (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_item_no_positive_chk
        CHECK (item_no > 0),

    CONSTRAINT export_application_item_quantity_nonneg_chk
        CHECK (quantity IS NULL OR quantity >= 0),

    CONSTRAINT export_application_item_commodity_class_chk
        CHECK (
            commodity_class IS NULL
            OR commodity_class IN (
                'LIVE_ANIMAL',
                'ANIMAL_PRODUCT',
                'EGG',
                'ANIMAL_BYPRODUCT',
                'AQUATIC_ANIMAL',
                'OTHER'
            )
        )
);

COMMENT ON TABLE trade.export_application_item IS
    'LVSP 000880: line items (commodity/species/product/quantity) of one export application. 1:N to casework.application via application_id. Not the same as trade.shipment_item (actual shipment goods, created later in the flow).';

-- ----------------------------------------------------------------------------
-- 3. Indexes (additive — ບໍ່ແຕະ index ເກົ່າ)
-- ----------------------------------------------------------------------------
-- NOTE: export_application_detail_application_id_key (UNIQUE) already creates
-- an implicit btree index on application_id; no extra index needed there.
-- NOTE: export_application_item_app_item_no_key (UNIQUE composite) already
-- creates an implicit btree index starting with application_id, but a plain
-- single-column index is added below too for lookups that don't filter by
-- item_no.

CREATE INDEX idx_export_application_item_application_id
    ON trade.export_application_item (application_id);

CREATE INDEX idx_export_application_item_species_id
    ON trade.export_application_item (species_id)
    WHERE species_id IS NOT NULL;

CREATE INDEX idx_export_application_item_product_id
    ON trade.export_application_item (product_id)
    WHERE product_id IS NOT NULL;

CREATE INDEX idx_export_application_item_unit_id
    ON trade.export_application_item (unit_id)
    WHERE unit_id IS NOT NULL;

CREATE INDEX idx_export_application_detail_service_type
    ON trade.export_application_detail (service_type);

CREATE INDEX idx_export_application_detail_destination_country_id
    ON trade.export_application_detail (destination_country_id)
    WHERE destination_country_id IS NOT NULL;

-- ============================================================================
-- END 000880 — 2 CREATE TABLE, 6 CREATE INDEX, 0 ALTER, 0 DROP, 0 DATA CHANGE.
-- ============================================================================
