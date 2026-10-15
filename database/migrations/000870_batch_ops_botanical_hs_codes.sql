-- =====================================================================
-- 000870_batch_ops_botanical_hs_codes.sql
-- LVSP Migration 000870 — Batch Operations + Botanical + HS/AHTN codes
-- APPEND-ONLY. NO BEGIN/COMMIT (runner wraps each file in its own txn).
-- Idempotent: IF NOT EXISTS / INSERT..WHERE NOT EXISTS / DROP..;CREATE.
-- =====================================================================

-- 1. registration.registration_type += 4 pathways ---------------------
INSERT INTO registration.registration_type(code,name_lo,name_en)
SELECT v.code, v.name_lo, v.name_en
FROM (VALUES
  ('IMPORT_FINISHED','ນຳເຂົ້າ (ຜະລິດຕະພັນສຳເລັດຮູບ)','Import (Finished Product)'),
  ('DOMESTIC_MANUFACTURE','ຜະລິດພາຍໃນປະເທດ','Domestic Manufacture'),
  ('IMPORT_BULK_REPACK','ນຳເຂົ້າ Bulk ເພື່ອບັນຈຸຄືນ','Import Bulk for Repack'),
  ('EXPORT','ສົ່ງອອກ','Export')
) AS v(code,name_lo,name_en)
WHERE NOT EXISTS (
  SELECT 1 FROM registration.registration_type rt WHERE rt.code = v.code
);

-- 2. product.product_type += TRADITIONAL_HERBAL -----------------------
INSERT INTO product.product_type(code,name_lo,name_en)
SELECT 'TRADITIONAL_HERBAL','ຜະລິດຕະພັນສະໝຸນໄພພື້ນເມືອງ','Traditional Herbal Product'
WHERE NOT EXISTS (
  SELECT 1 FROM product.product_type WHERE code='TRADITIONAL_HERBAL'
);

-- 3. reference_term BATCH_OPERATION_TYPE += REPACK/DECANT/RELABEL ------
INSERT INTO lookup.veterinary_drug_reference_term
  (domain_code,code,value_text,name_lo,name_en,sort_order)
SELECT v.domain_code,v.code,v.value_text,v.name_lo,v.name_en,v.sort_order
FROM (VALUES
  ('BATCH_OPERATION_TYPE','REPACK','Repack','ບັນຈຸຄືນ','Repack',10),
  ('BATCH_OPERATION_TYPE','DECANT','Decant','ຮ່າຍ (ແບ່ງບັນຈຸ)','Decant',20),
  ('BATCH_OPERATION_TYPE','RELABEL','Relabel','ຕິດສະຫຼາກຄືນ','Relabel',30)
) AS v(domain_code,code,value_text,name_lo,name_en,sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM lookup.veterinary_drug_reference_term t
  WHERE t.domain_code=v.domain_code AND t.code=v.code
);

-- 4. product.botanical_ingredient (multi-row per product) --------------
CREATE TABLE IF NOT EXISTS product.botanical_ingredient(
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id             uuid NOT NULL REFERENCES product.product(id),
  product_version_id     uuid REFERENCES product.product_version(id),
  sequence_no            int  NOT NULL DEFAULT 1,
  scientific_name        text NOT NULL,
  plant_family           text,
  common_name_lo         text,
  common_name_en         text,
  plant_part_ref_id      uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  preparation_ref_id     uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  extract_ratio          text,
  marker_substance       text,
  marker_qty             numeric,
  marker_unit            varchar(32),
  standardization_pct    numeric,
  source_ref_id          uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  origin_country         varchar(3),
  origin_locality        text,
  reference_monograph    text,
  quality_test_reference text,
  is_active              bool NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_botanical_product_seq UNIQUE(product_id, sequence_no)
);

-- 5. product.batch_operation (REPACK/DECANT/RELABEL event) -------------
CREATE TABLE IF NOT EXISTS product.batch_operation(
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type_ref_id   uuid NOT NULL REFERENCES lookup.veterinary_drug_reference_term(id),
  facility_id             uuid REFERENCES master.facility(id),
  source_registration_id  uuid REFERENCES registration.registration(id),
  source_import_item_id   uuid REFERENCES trade.import_application_item(id),
  secondary_gmp_reference text,
  bonded_flag             bool NOT NULL DEFAULT false,
  operation_date          date,
  notes                   text,
  is_active               bool NOT NULL DEFAULT true,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- 6. product.batch_operation_link (genealogy INPUT/OUTPUT) ------------
CREATE TABLE IF NOT EXISTS product.batch_operation_link(
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id  uuid NOT NULL REFERENCES product.batch_operation(id),
  batch_id      uuid NOT NULL REFERENCES product.batch(id),
  link_role     varchar(8) NOT NULL CHECK (link_role IN ('INPUT','OUTPUT')),
  quantity      numeric,
  unit_code     varchar(32),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_batch_op_link UNIQUE(operation_id, batch_id, link_role)
);

-- 7. ADD COLUMNS: INN / HS / AHTN / GTIN / GLN ------------------------
ALTER TABLE product.ingredient                 ADD COLUMN IF NOT EXISTS inn_code  varchar(255);
ALTER TABLE product.product_regulatory_profile ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE product.product_regulatory_profile ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE trade.import_application_item       ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE trade.import_application_item       ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE trade.import_plan_item              ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE trade.import_plan_item              ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE product.product                     ADD COLUMN IF NOT EXISTS gtin      varchar(14);
ALTER TABLE master.party                        ADD COLUMN IF NOT EXISTS gln       varchar(13);

-- 8. triggers on new tables ------------------------------------------
DROP TRIGGER IF EXISTS trg_botanical_ingredient_updated  ON product.botanical_ingredient;
CREATE TRIGGER trg_botanical_ingredient_updated
  BEFORE UPDATE ON product.botanical_ingredient
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
DROP TRIGGER IF EXISTS trg_botanical_ingredient_nodelete ON product.botanical_ingredient;
CREATE TRIGGER trg_botanical_ingredient_nodelete
  BEFORE DELETE ON product.botanical_ingredient
  FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_batch_operation_updated  ON product.batch_operation;
CREATE TRIGGER trg_batch_operation_updated
  BEFORE UPDATE ON product.batch_operation
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
DROP TRIGGER IF EXISTS trg_batch_operation_nodelete ON product.batch_operation;
CREATE TRIGGER trg_batch_operation_nodelete
  BEFORE DELETE ON product.batch_operation
  FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_batch_operation_link_updated ON product.batch_operation_link;
CREATE TRIGGER trg_batch_operation_link_updated
  BEFORE UPDATE ON product.batch_operation_link
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
