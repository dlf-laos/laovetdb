-- LVSP 000860 — Annual Trade Plan + National e-Cert Bridge Foundation
-- Additive integration over 000780/000790/000840 annual-plan architecture
-- and 000130/000530/000531/000850 certificate architecture.
--
-- SAFETY / DESIGN
-- * Existing annual-plan and certificate tables are retained.
-- * Existing regulatory records are not deleted or rewritten.
-- * Legal issuing authority and destination-country attestations are NOT hard-coded.
-- * Pet health certification is modeled for EXPORT only.
-- * New policy/profile rows remain DRAFT until competent legal/domain review.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('trade.import_plan') IS NULL THEN missing := array_append(missing,'trade.import_plan'); END IF;
  IF to_regclass('trade.import_plan_profile') IS NULL THEN missing := array_append(missing,'trade.import_plan_profile'); END IF;
  IF to_regclass('analytics.v_import_plan_tracking') IS NULL THEN missing := array_append(missing,'analytics.v_import_plan_tracking'); END IF;
  IF to_regclass('document.certificate') IS NULL THEN missing := array_append(missing,'document.certificate'); END IF;
  IF to_regclass('trade.health_certificate') IS NULL THEN missing := array_append(missing,'trade.health_certificate'); END IF;
  IF to_regclass('certification.ecert_document') IS NULL THEN missing := array_append(missing,'certification.ecert_document'); END IF;
  IF to_regclass('certification.ecert_module_policy') IS NULL THEN missing := array_append(missing,'certification.ecert_module_policy'); END IF;
  IF to_regclass('system.module_catalog') IS NULL THEN missing := array_append(missing,'system.module_catalog'); END IF;
  IF cardinality(missing)>0 THEN
    RAISE EXCEPTION '000860 prerequisites missing: %',array_to_string(missing,', ');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Broaden the EXISTING trade item classification without replacing tables.
-- ---------------------------------------------------------------------------

ALTER TABLE trade.import_plan_item
  DROP CONSTRAINT IF EXISTS import_plan_item_item_type_check;
ALTER TABLE trade.import_plan_item
  ADD CONSTRAINT ck_import_plan_item_type_v112 CHECK(item_type IN (
    'MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT',
    'FEED_PRODUCT','FEED_INGREDIENT','LIVE_ANIMAL','ANIMAL_PRODUCT','ANIMAL_BYPRODUCT',
    'EGG','AQUATIC_ANIMAL','AQUATIC_PRODUCT'
  )) NOT VALID;
ALTER TABLE trade.import_plan_item VALIDATE CONSTRAINT ck_import_plan_item_type_v112;

ALTER TABLE trade.import_application_item
  DROP CONSTRAINT IF EXISTS import_application_item_item_type_check;
ALTER TABLE trade.import_application_item
  ADD CONSTRAINT ck_import_application_item_type_v112 CHECK(item_type IN (
    'MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT',
    'FEED_PRODUCT','FEED_INGREDIENT','LIVE_ANIMAL','ANIMAL_PRODUCT','ANIMAL_BYPRODUCT',
    'EGG','AQUATIC_ANIMAL','AQUATIC_PRODUCT'
  )) NOT VALID;
ALTER TABLE trade.import_application_item VALIDATE CONSTRAINT ck_import_application_item_type_v112;

-- ---------------------------------------------------------------------------
-- 2) Annual Trade Plan service catalogue.
--    Physical table names trade.import_plan / import_plan_profile stay unchanged.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trade.annual_plan_service_type (
  service_type VARCHAR(80) PRIMARY KEY,
  module_code VARCHAR(100),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  annual_plan_required BOOLEAN NOT NULL DEFAULT TRUE,
  allowed_movements JSONB NOT NULL DEFAULT '["IMPORT"]'::jsonb,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_annual_plan_service_movements_array CHECK(jsonb_typeof(allowed_movements)='array')
);

INSERT INTO trade.annual_plan_service_type
(service_type,module_code,name_lo,name_en,annual_plan_required,allowed_movements,configuration_status,notes)
VALUES
('VET_DRUG_DEVICE','VET_DRUG_TRADE',
 'ຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Drugs & Devices',
 TRUE,'["IMPORT"]'::jsonb,'DRAFT',
 'Existing operational annual-plan work area; catalogue row does not change existing plan records.'),
('ANIMAL_FEED','ANIMAL_FEED_TRADE',
 'ອາຫານສັດ ແລະ ວັດຖຸປະສົມ/ວັດຖຸດິບອາຫານສັດ','Animal Feed & Feed Ingredients',
 TRUE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'Annual plan work area requested for import/export/transit; legal/SOP configuration remains subject to review.'),
('ANIMAL_PRODUCT','ANIMAL_PRODUCT_TRADE',
 'ຜະລິດຕະພັນກ່ຽວກັບສັດ','Animal Products',
 TRUE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'Annual plan work area requested for import/export/transit; certificate conditions remain destination-specific.'),
('LIVE_ANIMAL','ANIMAL_PRODUCT_TRADE',
 'ສັດມີຊີວິດ','Live Animals',
 FALSE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'No annual-plan requirement is asserted by this migration.'),
('PET_MOVEMENT','PET_MOVEMENT',
 'ໝາ-ແມວ / ສັດລ້ຽງມີຊີວິດ','Pet Dog/Cat Movement',
 FALSE,'["IMPORT","EXPORT"]'::jsonb,'DRAFT',
 'Pet movement is case/permit based; export may additionally produce a veterinary health certificate.')
ON CONFLICT(service_type) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_import_plan_profile_service_movement
  ON trade.import_plan_profile(service_type,movement_type);

COMMENT ON TABLE trade.annual_plan_service_type IS
'Configuration catalogue for the existing annual-plan engine. It does not replace trade.import_plan. DRAFT rows require legal/domain review before Production policy use.';
COMMENT ON COLUMN trade.import_plan_profile.service_type IS
'Annual Trade Plan work area. Existing physical table name is retained for backward compatibility.';

CREATE OR REPLACE FUNCTION trade.ensure_default_import_plan_profile()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO trade.import_plan_profile(import_plan_id,detail_level,movement_type,service_type)
  VALUES(NEW.id,'ITEM','IMPORT','VET_DRUG_DEVICE')
  ON CONFLICT(import_plan_id) DO NOTHING;
  RETURN NEW;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname='trg_import_plan_ensure_profile'
      AND tgrelid='trade.import_plan'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER trg_import_plan_ensure_profile
    AFTER INSERT ON trade.import_plan
    FOR EACH ROW EXECUTE FUNCTION trade.ensure_default_import_plan_profile();
  END IF;
END $$;

CREATE TRIGGER trg_annual_plan_service_type_updated_at
BEFORE UPDATE ON trade.annual_plan_service_type
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_annual_plan_service_type
BEFORE DELETE ON trade.annual_plan_service_type
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

-- ---------------------------------------------------------------------------
-- 3) Bridge established document.certificate to the 000850 national e-Cert registry.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS certification.ecert_legacy_certificate_link (
  ecert_id UUID PRIMARY KEY
    REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  legacy_certificate_id UUID NOT NULL UNIQUE
    REFERENCES document.certificate(id) ON DELETE RESTRICT,
  link_type VARCHAR(30) NOT NULL DEFAULT 'MIGRATION_BRIDGE'
    CHECK(link_type IN ('MIGRATION_BRIDGE','ISSUANCE_BRIDGE','MANUAL_LINK')),
  source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecert_legacy_link_certificate
  ON certification.ecert_legacy_certificate_link(legacy_certificate_id);

CREATE TRIGGER trg_no_delete_ecert_legacy_certificate_link
BEFORE DELETE ON certification.ecert_legacy_certificate_link
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE certification.ecert_legacy_certificate_link IS
'Non-destructive one-to-one bridge between document.certificate and the national 000850 e-Cert registry. No legacy certificate is copied, replaced or deleted.';

-- ---------------------------------------------------------------------------
-- 4) Configurable international/destination certificate profiles.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS certification.ecert_profile (
  profile_code VARCHAR(120) PRIMARY KEY,
  profile_name_lo TEXT NOT NULL,
  profile_name_en TEXT NOT NULL,
  document_type_code VARCHAR(120) NOT NULL,
  source_module_code VARCHAR(100) NOT NULL,
  movement_type VARCHAR(20) NOT NULL
    CHECK(movement_type IN ('IMPORT','EXPORT','TRANSIT','RE_EXPORT')),
  subject_scope VARCHAR(40) NOT NULL
    CHECK(subject_scope IN ('PET','LIVE_ANIMAL','ANIMAL_PRODUCT','FEED','OTHER')),
  origin_country_code VARCHAR(3),
  destination_country_code VARCHAR(3),
  standard_profile VARCHAR(80) NOT NULL DEFAULT 'UNCEFACT_ECERT',
  standard_version TEXT,
  effective_from DATE,
  effective_to DATE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  legal_reference TEXT,
  validity_rule JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_ecert_profile_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from),
  CONSTRAINT ck_ecert_profile_validity_rule CHECK(jsonb_typeof(validity_rule)='object')
);

CREATE INDEX IF NOT EXISTS idx_ecert_profile_lookup
  ON certification.ecert_profile(source_module_code,document_type_code,movement_type,destination_country_code,configuration_status);

CREATE TABLE IF NOT EXISTS certification.ecert_profile_attestation (
  attestation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_code VARCHAR(120) NOT NULL
    REFERENCES certification.ecert_profile(profile_code) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK(sequence_no>0),
  attestation_code VARCHAR(120) NOT NULL,
  clause_text_lo TEXT,
  clause_text_en TEXT,
  rule_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_required BOOLEAN NOT NULL DEFAULT FALSE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  legal_reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(profile_code,sequence_no),
  UNIQUE(profile_code,attestation_code),
  CONSTRAINT ck_ecert_profile_attestation_rule CHECK(jsonb_typeof(rule_payload)='object')
);

CREATE INDEX IF NOT EXISTS idx_ecert_profile_attestation_profile
  ON certification.ecert_profile_attestation(profile_code,sequence_no,configuration_status);

INSERT INTO certification.ecert_profile
(profile_code,profile_name_lo,profile_name_en,document_type_code,source_module_code,movement_type,subject_scope,configuration_status,notes)
VALUES
('PET_EXPORT_HEALTH_BASE',
 'ໃບຢັ້ງຢືນສຸຂະພາບສັດລ້ຽງສຳລັບສົ່ງອອກ',
 'Pet Export Veterinary Health Certificate',
 'PET_EXPORT_HEALTH_CERTIFICATE','PET_MOVEMENT','EXPORT','PET','DRAFT',
 'Base structural profile only. Destination-country attestations, validity and competent issuing authority are not hard-coded.'),
('LIVE_ANIMAL_EXPORT_HEALTH_BASE',
 'ໃບຢັ້ງຢືນສຸຂະພາບສັດມີຊີວິດສຳລັບສົ່ງອອກ',
 'Live Animal Export Veterinary Health Certificate',
 'LIVE_ANIMAL_EXPORT_HEALTH_CERTIFICATE','ANIMAL_PRODUCT_TRADE','EXPORT','LIVE_ANIMAL','DRAFT',
 'Base structural profile only; species/destination attestations remain configurable.'),
('ANIMAL_PRODUCT_EXPORT_SANITARY_BASE',
 'ໃບຢັ້ງຢືນສຸຂະນາໄມຜະລິດຕະພັນສັດສຳລັບສົ່ງອອກ',
 'Animal Product Export Veterinary/Sanitary Certificate',
 'ANIMAL_PRODUCT_EXPORT_SANITARY_CERTIFICATE','ANIMAL_PRODUCT_TRADE','EXPORT','ANIMAL_PRODUCT','DRAFT',
 'Base structural profile only; commodity/destination attestations remain configurable.')
ON CONFLICT(profile_code) DO NOTHING;

CREATE TRIGGER trg_ecert_profile_updated_at
BEFORE UPDATE ON certification.ecert_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_ecert_profile_attestation_updated_at
BEFORE UPDATE ON certification.ecert_profile_attestation
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_ecert_profile
BEFORE DELETE ON certification.ecert_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_ecert_profile_attestation
BEFORE DELETE ON certification.ecert_profile_attestation
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE certification.ecert_profile IS
'Configurable certificate profile metadata. DRAFT does not constitute approved legal wording or issuing authority.';
COMMENT ON TABLE certification.ecert_profile_attestation IS
'Destination/species/commodity attestation clauses. No clause is seeded as legally approved by 000860.';

-- ---------------------------------------------------------------------------
-- 5) Module catalogue and e-Cert policy stubs.
-- ---------------------------------------------------------------------------

INSERT INTO system.module_catalog
(module_code,module_key,name_lo,name_en,description_lo,description_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order)
VALUES
('PET_MOVEMENT','pet_movement',
 'ນຳເຂົ້າ-ສົ່ງອອກ ໝາ-ແມວ','Pet Import / Export',
 'ຄຳຮ້ອງ ໃບອະນຸຍາດ ແລະ ໃບຢັ້ງຢືນສຸຂະພາບສຳລັບການສົ່ງອອກ',
 'Pet movement applications, permits and export veterinary health certificates',
 '🐕','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',205)
ON CONFLICT(module_code) DO NOTHING;

INSERT INTO certification.ecert_module_policy
(module_code,document_type_code,lifecycle_enabled,public_verification_enabled,g2g_exchange_enabled,electronic_only_enabled,paper_fallback_allowed,standard_profile,configuration_status,notes)
VALUES
('PET_MOVEMENT','PET_IMPORT_PERMIT',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Pet import permit foundation. This migration does not create a Lao export-style health certificate for import.'),
('PET_MOVEMENT','PET_EXPORT_PERMIT',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Pet export permit foundation.'),
('PET_MOVEMENT','PET_EXPORT_HEALTH_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Export-only pet veterinary health certificate foundation; destination requirements are profile-driven.'),
('ANIMAL_PRODUCT_TRADE','LIVE_ANIMAL_EXPORT_HEALTH_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Live-animal export certificate foundation; species/destination requirements are not hard-coded.'),
('ANIMAL_PRODUCT_TRADE','ANIMAL_PRODUCT_EXPORT_SANITARY_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Animal-product export sanitary certificate foundation; commodity/destination requirements are not hard-coded.')
ON CONFLICT(module_code,document_type_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6) Cross-work-area annual-plan overview without replacing 000840 analytics.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_annual_trade_plan_overview AS
SELECT
  p.id AS plan_id,
  p.plan_no,
  p.plan_year,
  p.company_id,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
  COALESCE(pp.service_type,'VET_DRUG_DEVICE') AS service_type,
  st.module_code,
  COALESCE(st.name_lo,pp.service_type,'VET_DRUG_DEVICE') AS service_name_lo,
  COALESCE(st.name_en,pp.service_type,'Veterinary Drugs & Devices') AS service_name_en,
  COALESCE(pp.movement_type,'IMPORT') AS movement_type,
  COALESCE(pp.detail_level,'ITEM') AS detail_level,
  COALESCE(st.annual_plan_required,TRUE) AS annual_plan_required,
  p.application_date,
  p.approval_no,
  p.approval_date,
  p.status,
  COUNT(t.plan_item_id)::INTEGER AS item_count,
  COUNT(*) FILTER (WHERE t.tracking_status='OVER_PLAN')::INTEGER AS over_plan_item_count,
  COUNT(*) FILTER (WHERE t.tracking_status='EXHAUSTED')::INTEGER AS exhausted_item_count,
  COALESCE(SUM(t.approved_value_usd),0)::NUMERIC(20,2) AS approved_value_usd,
  COALESCE(SUM(t.actual_cleared_value_usd),0)::NUMERIC(20,2) AS actual_cleared_value_usd
FROM trade.import_plan p
LEFT JOIN master.company c ON c.party_id=p.company_id
LEFT JOIN trade.import_plan_profile pp ON pp.import_plan_id=p.id
LEFT JOIN trade.annual_plan_service_type st
  ON st.service_type=COALESCE(pp.service_type,'VET_DRUG_DEVICE')
LEFT JOIN analytics.v_import_plan_tracking t ON t.plan_id=p.id
GROUP BY
  p.id,p.plan_no,p.plan_year,p.company_id,c.legal_name_lo,c.legal_name_en,
  pp.service_type,pp.movement_type,pp.detail_level,
  st.module_code,st.name_lo,st.name_en,st.annual_plan_required,
  p.application_date,p.approval_no,p.approval_date,p.status;

COMMENT ON VIEW analytics.v_annual_trade_plan_overview IS
'Cross-work-area Annual Trade Plan overview layered on the existing 000780/000790/000840 plan engine. Existing import analytics remain intact.';

-- ===========================================================================
-- 7) DLF/DVS governance foundation — responsibilities can change over time.
--    Baseline rows below are PROVISIONAL, based on the DVS 2025 mandate
--    supplied for LVSP design. They are NOT a permanent legal assignment and
--    are deliberately effective-dated/configurable for future 2026+ changes.
-- ===========================================================================

CREATE SCHEMA IF NOT EXISTS governance;
CREATE SCHEMA IF NOT EXISTS integration;

CREATE TABLE IF NOT EXISTS governance.organizational_unit (
  unit_code VARCHAR(100) PRIMARY KEY,
  parent_unit_code VARCHAR(100)
    REFERENCES governance.organizational_unit(unit_code) ON DELETE RESTRICT,
  unit_type VARCHAR(30) NOT NULL
    CHECK(unit_type IN ('DEPARTMENT','DIVISION','CENTER','OFFICE','OTHER')),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from DATE,
  valid_to DATE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_governance_unit_dates
    CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from)
);

INSERT INTO governance.organizational_unit
(unit_code,parent_unit_code,unit_type,name_lo,name_en,configuration_status,notes)
VALUES
('DLF',NULL,'DEPARTMENT',
 'ກົມລ້ຽງສັດ ແລະ ການປະມົງ',
 'Department of Livestock and Fisheries','DRAFT',
 'DLF organizational root for configurable LVSP responsibility mapping.'),
('DVS','DLF','DIVISION',
 'ພະແນກສັດຕະວະແພດ',
 'Division of Veterinary Services','DRAFT',
 'Current LVSP domain unit.'),
('LIVESTOCK_DIVISION','DLF','DIVISION',
 'ພະແນກລ້ຽງສັດ',
 'Livestock Division','DRAFT',
 'Name/code is a configurable integration placeholder; confirm against the current DLF organization list.'),
('ANIMAL_DISEASE_DIAGNOSTIC_CENTER','DLF','CENTER',
 'ສູນວິໄຈພະຍາດສັດ',
 'Animal Disease Diagnostic Center','DRAFT',
 'External service owner placeholder for laboratory/sample testing; confirm official 2026 name and mandate.')
ON CONFLICT(unit_code) DO NOTHING;

CREATE TRIGGER trg_governance_organizational_unit_updated_at
BEFORE UPDATE ON governance.organizational_unit
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_governance_organizational_unit
BEFORE DELETE ON governance.organizational_unit
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS governance.service_catalog (
  service_code VARCHAR(120) PRIMARY KEY,
  domain_code VARCHAR(80) NOT NULL,
  module_code VARCHAR(100),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  service_kind VARCHAR(40) NOT NULL
    CHECK(service_kind IN ('REGISTRATION','PERMIT','CERTIFICATE','TRADE','INSPECTION','SURVEILLANCE','LAB_SERVICE','OTHER')),
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO governance.service_catalog
(service_code,domain_code,module_code,name_lo,name_en,service_kind,configuration_status,notes)
VALUES
('VET_DRUG_REGISTRATION','VETERINARY_PRODUCTS','VM-1003',
 'ຂຶ້ນທະບຽນຢາ ແລະ ຜະລິດຕະພັນສັດຕະວະແພດ',
 'Veterinary Drug/Product Registration','REGISTRATION','DRAFT',
 'DVS core business service.'),
('VET_DRUG_TRADE','VETERINARY_PRODUCTS','VET_DRUG_TRADE',
 'ນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ',
 'Veterinary Drug/Device Trade','TRADE','DRAFT',
 'DVS core trade service.'),
('PET_MOVEMENT','ANIMAL_MOVEMENT','PET_MOVEMENT',
 'ນຳເຂົ້າ-ສົ່ງອອກ ໝາ-ແມວ',
 'Pet Dog/Cat Movement','PERMIT','DRAFT',
 'DVS pet movement service; export may include veterinary health certification.'),
('ANIMAL_PRODUCT_TRADE','ANIMAL_PRODUCTS','ANIMAL_PRODUCT_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ຜະລິດຕະພັນສັດ',
 'Animal Product Trade','TRADE','DRAFT',
 'DVS has veterinary/sanitary/risk responsibilities; whole administrative ownership must remain configurable.'),
('LIVE_ANIMAL_TRADE','ANIMAL_MOVEMENT','LIVE_ANIMAL_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ສັດມີຊີວິດ',
 'Live Animal Trade','TRADE','DRAFT',
 '2025 mandate indicates joint consideration with Livestock Division.'),
('ANIMAL_FEED_TRADE','FEED','ANIMAL_FEED_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ອາຫານສັດ ແລະ ວັດຖຸປະສົມ',
 'Animal Feed and Feed Ingredient Trade','TRADE','DRAFT',
 'DVS ownership is UNCONFIRMED pending the updated mandate.'),
('LAB_TESTING','ANIMAL_HEALTH','LAB',
 'ການເກັບ/ສົ່ງຕົວຢ່າງ ແລະ ການວິໄຈ',
 'Sample Referral and Laboratory Testing','LAB_SERVICE','DRAFT',
 'Laboratory service is treated as an external DLF-center service, not an LVSP laboratory system.'),
('EPIDEMIOLOGY_SURVEILLANCE','ANIMAL_HEALTH','AH-1001',
 'ລະບາດວິທະຍາ ແລະ ເຝົ້າລະວັງພະຍາດສັດ',
 'Veterinary Epidemiology and Surveillance','SURVEILLANCE','DRAFT',
 'DVS core animal-health responsibility.'),
('VETERINARY_BORDER_INSPECTION','BORDER','BORDER_INSPECTION',
 'ດ່ານ ແລະ ການກວດກາສັດຕະວະແພດ',
 'Veterinary Border/Checkpoint Inspection','INSPECTION','DRAFT',
 'DVS veterinary checkpoint/inspection responsibility.'),
('MEAT_HYGIENE','ANIMAL_PRODUCTS','MEAT_HYGIENE',
 'ກວດກາອະນາໄມຊີ້ນ ແລະ ສະຖານປະກອບການ',
 'Meat Hygiene and Establishment Control','INSPECTION','DRAFT',
 'DVS 2025 mandate includes meat hygiene, slaughterhouse/cold-storage related functions.')
ON CONFLICT(service_code) DO NOTHING;

CREATE TRIGGER trg_governance_service_catalog_updated_at
BEFORE UPDATE ON governance.service_catalog
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_governance_service_catalog
BEFORE DELETE ON governance.service_catalog
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS governance.service_scope_history (
  scope_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_code VARCHAR(120) NOT NULL
    REFERENCES governance.service_catalog(service_code) ON DELETE RESTRICT,
  dvs_responsibility_class VARCHAR(30) NOT NULL
    CHECK(dvs_responsibility_class IN ('DVS_LEAD','DVS_PARTICIPANT','EXTERNAL_OWNER','UNCONFIRMED')),
  lead_unit_code VARCHAR(100)
    REFERENCES governance.organizational_unit(unit_code) ON DELETE RESTRICT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  basis_version VARCHAR(80) NOT NULL,
  legal_reference TEXT,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_service_scope_dates
    CHECK(effective_to IS NULL OR effective_to>=effective_from)
);

CREATE INDEX IF NOT EXISTS idx_service_scope_history_lookup
  ON governance.service_scope_history(service_code,effective_from,effective_to,configuration_status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_service_scope_history_version
  ON governance.service_scope_history(service_code,basis_version,effective_from);

INSERT INTO governance.service_scope_history
(service_code,dvs_responsibility_class,lead_unit_code,effective_from,basis_version,configuration_status,notes)
VALUES
('VET_DRUG_REGISTRATION','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional baseline pending 2026 mandate confirmation.'),
('VET_DRUG_TRADE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional baseline pending 2026 mandate confirmation.'),
('PET_MOVEMENT','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Pet movement/certification remains configurable if responsibilities change.'),
('ANIMAL_PRODUCT_TRADE','DVS_PARTICIPANT','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'DVS veterinary/sanitary/risk role is recognized; whole administrative ownership is not hard-coded.'),
('LIVE_ANIMAL_TRADE','DVS_PARTICIPANT','LIVESTOCK_DIVISION',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 '2025 mandate indicates joint consideration with Livestock Division.'),
('ANIMAL_FEED_TRADE','UNCONFIRMED',NULL,DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Feed trade ownership is intentionally unconfirmed until updated DLF/DVS mandate is obtained.'),
('LAB_TESTING','EXTERNAL_OWNER','ANIMAL_DISEASE_DIAGNOSTIC_CENTER',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'LVSP may refer a sample/request and receive a result/reference; it does not become the laboratory system.'),
('EPIDEMIOLOGY_SURVEILLANCE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.'),
('VETERINARY_BORDER_INSPECTION','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.'),
('MEAT_HYGIENE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.')
ON CONFLICT DO NOTHING;

CREATE TRIGGER trg_no_delete_governance_service_scope_history
BEFORE DELETE ON governance.service_scope_history
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE OR REPLACE VIEW governance.v_current_service_scope AS
SELECT DISTINCT ON (h.service_code)
  h.scope_id,
  h.service_code,
  s.domain_code,
  s.module_code,
  s.name_lo,
  s.name_en,
  h.dvs_responsibility_class,
  h.lead_unit_code,
  u.name_lo AS lead_unit_name_lo,
  u.name_en AS lead_unit_name_en,
  h.effective_from,
  h.effective_to,
  h.basis_version,
  h.legal_reference,
  h.configuration_status,
  h.notes
FROM governance.service_scope_history h
JOIN governance.service_catalog s ON s.service_code=h.service_code
LEFT JOIN governance.organizational_unit u ON u.unit_code=h.lead_unit_code
WHERE h.effective_from<=CURRENT_DATE
  AND (h.effective_to IS NULL OR h.effective_to>=CURRENT_DATE)
ORDER BY h.service_code,h.effective_from DESC,h.created_at DESC;

COMMENT ON VIEW governance.v_current_service_scope IS
'Effective-dated DVS responsibility view. Organizational restructuring is represented by new history rows, never by rewriting historical cases.';

-- ===========================================================================
-- 8) Single Window / inter-agency integration foundation.
--    No Customs, LNSW, DLF, Fisheries, Livestock or Lab URL/auth is hard-coded.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS integration.external_system (
  system_code VARCHAR(80) PRIMARY KEY,
  system_name TEXT NOT NULL,
  agency_name TEXT NOT NULL,
  system_type VARCHAR(30) NOT NULL
    CHECK(system_type IN ('DLF_INTERNAL','MINISTRY','CUSTOMS','SINGLE_WINDOW','LAB','OTHER_GOV','FOREIGN_GOV','OTHER')),
  environment VARCHAR(20) NOT NULL DEFAULT 'PLANNED'
    CHECK(environment IN ('PLANNED','DEV','STAGING','PRODUCTION')),
  protocol VARCHAR(30) NOT NULL DEFAULT 'REST'
    CHECK(protocol IN ('REST','SOAP','SFTP','MESSAGE_QUEUE','MANUAL','OTHER')),
  authentication_method VARCHAR(40) NOT NULL DEFAULT 'UNCONFIGURED',
  base_url TEXT,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO integration.external_system
(system_code,system_name,agency_name,system_type,environment,protocol,authentication_method,configuration_status,notes)
VALUES
('DLF_GATEWAY','DLF Integration Gateway','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future DLF service/API gateway; URL and authentication intentionally blank.'),
('LIVESTOCK_SYSTEM','Livestock Division System','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future division system integration placeholder.'),
('FISHERIES_SYSTEM','Fisheries System','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future fisheries system integration placeholder.'),
('DIAGNOSTIC_LAB','Animal Disease Diagnostic Center System','Department of Livestock and Fisheries','LAB','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future lab referral/result integration placeholder.'),
('CUSTOMS','Lao Customs System','Lao Customs','CUSTOMS','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Customs integration placeholder only; no endpoint or credential is hard-coded.'),
('LNSW','Lao National Single Window','Lao PDR','SINGLE_WINDOW','PLANNED','REST','UNCONFIGURED','DRAFT',
 'National Single Window integration placeholder only; no endpoint or credential is hard-coded.')
ON CONFLICT(system_code) DO NOTHING;

CREATE TRIGGER trg_integration_external_system_updated_at
BEFORE UPDATE ON integration.external_system
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_integration_external_system
BEFORE DELETE ON integration.external_system
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS integration.external_identifier (
  external_identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(80) NOT NULL,
  internal_reference TEXT NOT NULL,
  external_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  external_id TEXT NOT NULL,
  namespace TEXT,
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK(status IN ('ACTIVE','INACTIVE','REPLACED','REVOKED')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_external_identifier_metadata CHECK(jsonb_typeof(metadata)='object'),
  CONSTRAINT ck_external_identifier_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from),
  UNIQUE(external_system_code,entity_type,external_id)
);

CREATE INDEX IF NOT EXISTS idx_external_identifier_internal
  ON integration.external_identifier(entity_type,internal_reference,status);

CREATE TRIGGER trg_no_delete_integration_external_identifier
BEFORE DELETE ON integration.external_identifier
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS integration.message_envelope (
  message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_type VARCHAR(100) NOT NULL,
  schema_version VARCHAR(30) NOT NULL DEFAULT '1.0',
  source_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  destination_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  correlation_id UUID NOT NULL DEFAULT gen_random_uuid(),
  reference_type VARCHAR(80),
  reference_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(status IN ('DRAFT','QUEUED','SENT','ACKNOWLEDGED','REJECTED','FAILED','CANCELLED')),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_integration_message_payload CHECK(jsonb_typeof(payload)='object')
);

CREATE INDEX IF NOT EXISTS idx_integration_message_correlation
  ON integration.message_envelope(correlation_id);
CREATE INDEX IF NOT EXISTS idx_integration_message_reference
  ON integration.message_envelope(reference_type,reference_id);
CREATE INDEX IF NOT EXISTS idx_integration_message_status
  ON integration.message_envelope(status,created_at);

CREATE TRIGGER trg_integration_message_envelope_updated_at
BEFORE UPDATE ON integration.message_envelope
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_integration_message_envelope
BEFORE DELETE ON integration.message_envelope
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE integration.message_envelope IS
'Generic future DLF/Customs/LNSW/non-certificate message envelope. certification.ecert_exchange_message remains the authoritative e-Cert exchange model from 000850.';

CREATE OR REPLACE VIEW integration.v_single_window_readiness AS
SELECT
  e.system_code,
  e.system_name,
  e.agency_name,
  e.system_type,
  e.environment,
  e.protocol,
  e.authentication_method,
  (e.base_url IS NOT NULL AND length(trim(e.base_url))>0) AS endpoint_configured,
  e.configuration_status,
  e.notes
FROM integration.external_system e
ORDER BY e.system_type,e.system_code;

COMMENT ON VIEW integration.v_single_window_readiness IS
'Readiness/configuration view only. DRAFT/PLANNED rows do not imply a live external connection.';

-- Keep Annual Trade Plan catalog broad but prevent the migration from claiming
-- DVS ownership for feed/live-animal work.
UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for future/shared integration. DVS ownership is UNCONFIRMED pending updated mandate.',
    configuration_status='DRAFT'
WHERE service_type='ANIMAL_FEED';

UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for shared workflow. 2025 baseline treats DVS as a PARTICIPANT, not sole owner.',
    configuration_status='DRAFT'
WHERE service_type='LIVE_ANIMAL';

UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for veterinary/sanitary participation. Whole administrative ownership remains configurable.',
    configuration_status='DRAFT'
WHERE service_type='ANIMAL_PRODUCT';

