-- LVSP 000810: Legacy Registration + Trade Parity Pack
-- Date: 2026-08-14
--
-- PURPOSE
--   Preserve high-value operational functions from the legacy Veterinary System
--   inside the existing LVSP PostgreSQL architecture. This migration is additive.
--
-- SCOPE
--   1) One internal registration memo -> many veterinary drug registrations.
--      One product stays one memo row; selected package/presentation sub-registrations
--      are grouped inside that row and snapshotted for official history.
--   2) Import/export/transit coordination review checklist with the legacy IET
--      document-presence / document-quality review behaviour.
--   3) Stable analytics views for the shared regulatory report builder.
--
-- NON-DESTRUCTIVE
--   No DROP TABLE. No DELETE. Existing issued records are not rewritten.
--   Snapshots are intentionally JSONB because they are issued-document history.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('product.product_regulatory_profile') IS NULL THEN
    missing := array_append(missing,'product.product_regulatory_profile');
  END IF;
  IF to_regclass('product.package') IS NULL THEN
    missing := array_append(missing,'product.package');
  END IF;
  IF to_regclass('trade.import_application') IS NULL THEN
    missing := array_append(missing,'trade.import_application');
  END IF;
  IF to_regclass('trade.import_application_item') IS NULL THEN
    missing := array_append(missing,'trade.import_application_item');
  END IF;
  IF to_regclass('security.app_user') IS NULL THEN
    missing := array_append(missing,'security.app_user');
  END IF;
  IF cardinality(missing) > 0 THEN
    RAISE EXCEPTION '000810 prerequisites missing: %', array_to_string(missing,', ');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Internal registration memo / cover sheet
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_internal_memo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_no VARCHAR(120),
  memo_suffix VARCHAR(40) NOT NULL DEFAULT 'ພສວພ',
  memo_date DATE NOT NULL DEFAULT current_date,
  place_text TEXT NOT NULL DEFAULT 'ນະຄອນຫຼວງວຽງຈັນ',

  organization_name TEXT NOT NULL DEFAULT 'ກົມລ້ຽງສັດ ແລະ ການປະມົງ',
  department_name TEXT NOT NULL DEFAULT 'ພະແນກສັດຕະວະແພດ',
  recipient TEXT NOT NULL DEFAULT 'ຫົວໜ້າກົມລ້ຽງສັດ ແລະ ການປະມົງ',
  subject_text TEXT,
  lead_text TEXT,

  purposes JSONB NOT NULL DEFAULT '["approve"]'::jsonb,
  company_auto BOOLEAN NOT NULL DEFAULT TRUE,
  group_by_company BOOLEAN NOT NULL DEFAULT TRUE,
  show_lao BOOLEAN NOT NULL DEFAULT TRUE,
  show_sub_registration BOOLEAN NOT NULL DEFAULT TRUE,
  show_pack BOOLEAN NOT NULL DEFAULT TRUE,
  show_category BOOLEAN NOT NULL DEFAULT TRUE,

  staff_lines JSONB NOT NULL DEFAULT '[]'::jsonb,
  signatory_names JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,

  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT','READY','SIGNED','ARCHIVED','CANCELLED')),
  created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_internal_memo_purposes_array
    CHECK (jsonb_typeof(purposes) = 'array'),
  CONSTRAINT ck_vet_drug_internal_memo_staff_array
    CHECK (jsonb_typeof(staff_lines) = 'array'),
  CONSTRAINT ck_vet_drug_internal_memo_signatories_object
    CHECK (jsonb_typeof(signatory_names) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_internal_memo_date
  ON registration.veterinary_drug_internal_memo(memo_date DESC,status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_internal_memo_no
  ON registration.veterinary_drug_internal_memo(memo_no,memo_suffix)
  WHERE memo_no IS NOT NULL AND btrim(memo_no) <> '' AND status <> 'CANCELLED';

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_internal_memo_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_internal_memo(id) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK (sequence_no > 0),

  regulatory_profile_id UUID NOT NULL
    REFERENCES product.product_regulatory_profile(id) ON DELETE RESTRICT,
  application_id UUID
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,
  registration_id UUID
    REFERENCES registration.registration(id) ON DELETE RESTRICT,

  registration_no_snapshot TEXT,
  trade_name_snapshot TEXT NOT NULL,
  generic_name_snapshot TEXT,
  category_snapshot TEXT,
  dosage_form_snapshot TEXT,
  holder_snapshot TEXT,
  manufacturer_snapshot TEXT,
  selected_presentations JSONB NOT NULL DEFAULT '[]'::jsonb,
  source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,

  record_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK (record_status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_memo_item_presentations_array
    CHECK (jsonb_typeof(selected_presentations) = 'array'),
  CONSTRAINT ck_vet_drug_memo_item_source_object
    CHECK (jsonb_typeof(source_snapshot) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_memo_item_active_sequence
  ON registration.veterinary_drug_internal_memo_item(memo_id,sequence_no)
  WHERE record_status='ACTIVE';
CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_memo_item_active_profile
  ON registration.veterinary_drug_internal_memo_item(memo_id,regulatory_profile_id)
  WHERE record_status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_vet_drug_memo_item_profile
  ON registration.veterinary_drug_internal_memo_item(regulatory_profile_id,created_at DESC);

-- ---------------------------------------------------------------------------
-- 2. Trade coordination / document review sheet
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lookup.regulatory_coordination_requirement (
  requirement_code VARCHAR(80) PRIMARY KEY,
  scope_code VARCHAR(60) NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no > 0),
  label_lo TEXT NOT NULL,
  label_en TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  configuration_status VARCHAR(40) NOT NULL DEFAULT 'LEGACY_OPERATIONAL_REFERENCE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(scope_code,sequence_no)
);

INSERT INTO lookup.regulatory_coordination_requirement
(requirement_code,scope_code,sequence_no,label_lo,label_en)
VALUES
('IET_APPLICATION_FORM','VET_DRUG_DEVICE_TRADE',1,'ໃບຄຳຮ້ອງ / ແບບຟອມ (IET 1 / IET 4)','Application / form (IET 1 / IET 4)'),
('ORIGIN_EXPORT_PERMIT','VET_DRUG_DEVICE_TRADE',2,'ໃບອະນຸຍາດສົ່ງອອກຈາກປະເທດຕົ້ນທາງ','Export permit from country of origin'),
('ANALYSIS_REPORT','VET_DRUG_DEVICE_TRADE',3,'ບົດວິໄຈ ແລະ ບົດລາຍງານ (IET 2 / IET 3)','Analysis / report (IET 2 / IET 3)'),
('INVOICE_PACKING_LIST','VET_DRUG_DEVICE_TRADE',4,'ໃບຢັ້ງຢືນລາຍການສິນຄ້າ (Invoice & Packing list)','Invoice & Packing list'),
('GMP_HACCP','VET_DRUG_DEVICE_TRADE',5,'ໃບຢັ້ງຢືນມາດຕະຖານການຜະລິດ (GMP / HACCP)','GMP / HACCP certificate'),
('HEALTH_QUALITY_CERT','VET_DRUG_DEVICE_TRADE',6,'ໃບຢັ້ງຢືນສຸຂະພາບສັດ / ຄຸນນະພາບສິນຄ້າ','Animal health / product quality certificate'),
('PRODUCT_REGISTRATION','VET_DRUG_DEVICE_TRADE',7,'ໃບຂຶ້ນທະບຽນຢາ / ຜະລິດຕະພັນ (ຖ້າມີ)','Drug / product registration (if applicable)'),
('OTHER_DOCUMENTS','VET_DRUG_DEVICE_TRADE',8,'ເອກະສານອື່ນໆ (ຖ້າມີ)','Other documents (if applicable)')
ON CONFLICT (requirement_code) DO UPDATE SET
  scope_code=EXCLUDED.scope_code,
  sequence_no=EXCLUDED.sequence_no,
  label_lo=EXCLUDED.label_lo,
  label_en=EXCLUDED.label_en,
  is_active=TRUE,
  updated_at=now();

CREATE TABLE IF NOT EXISTS trade.application_coordination_sheet (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL UNIQUE
    REFERENCES trade.import_application(id) ON DELETE RESTRICT,
  sheet_no VARCHAR(120),
  sheet_date DATE NOT NULL DEFAULT current_date,
  subject_text TEXT,
  overall_comment TEXT,
  reviewer_name TEXT,
  reviewer_position TEXT,
  head_section_name TEXT,
  deputy_director_comment TEXT,
  signatory_names JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(status IN ('DRAFT','REVIEWED','READY','SIGNED','ARCHIVED','CANCELLED')),
  created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_trade_coord_signatories_object CHECK(jsonb_typeof(signatory_names)='object')
);

CREATE INDEX IF NOT EXISTS idx_trade_coord_sheet_status
  ON trade.application_coordination_sheet(status,sheet_date DESC);

CREATE TABLE IF NOT EXISTS trade.application_coordination_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheet_id UUID NOT NULL
    REFERENCES trade.application_coordination_sheet(id) ON DELETE RESTRICT,
  requirement_code VARCHAR(80) NOT NULL
    REFERENCES lookup.regulatory_coordination_requirement(requirement_code) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK(sequence_no > 0),
  label_snapshot TEXT NOT NULL,
  presence_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
    CHECK(presence_status IN ('PENDING','PRESENT','MISSING','NOT_APPLICABLE')),
  quality_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
    CHECK(quality_status IN ('PENDING','CORRECT','INCORRECT','POLICY','NOT_APPLICABLE')),
  reference_no TEXT,
  notes TEXT,
  document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  record_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK(record_status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_trade_coord_item_active_requirement
  ON trade.application_coordination_item(sheet_id,requirement_code)
  WHERE record_status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_trade_coord_item_sheet
  ON trade.application_coordination_item(sheet_id,sequence_no,record_status);

-- ---------------------------------------------------------------------------
-- 3. Shared Regulatory Report Builder views
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_veterinary_drug_registry_report AS
SELECT
  pr.id AS regulatory_profile_id,
  pr.product_id,
  pr.registration_no,
  pr.dlf_no,
  pr.dlf_date,
  pr.application_date,
  pr.issue_date,
  pr.expiry_date,
  pr.trade_name,
  pr.generic_name,
  pr.active_ingredients,
  pr.category,
  pr.dosage_form,
  pr.registration_type,
  COALESCE(h.legal_name_lo,h.legal_name_en) AS registration_holder,
  COALESCE(i.legal_name_lo,i.legal_name_en) AS importer,
  pr.manufacturer_name,
  pr.manufacturer_country,
  pr.valid_years,
  pr.registration_status,
  COALESCE(pkg.presentation_count,0) AS presentation_count,
  pr.created_at,
  pr.updated_at
FROM product.product_regulatory_profile pr
LEFT JOIN master.company h ON h.party_id=pr.holder_company_id
LEFT JOIN master.company i ON i.party_id=pr.importer_company_id
LEFT JOIN LATERAL (
  SELECT count(*)::int AS presentation_count
  FROM product.package p
  WHERE p.product_id=pr.product_id
    AND COALESCE(p.presentation_status,'ACTIVE')<>'INACTIVE'
) pkg ON TRUE;

CREATE OR REPLACE VIEW analytics.v_veterinary_trade_permit_report AS
SELECT
  ia.id AS application_id,
  ia.application_no,
  ia.permit_no,
  ia.import_type AS movement_type,
  ia.application_date,
  ia.decision_date,
  ia.cleared_date,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS operator_name,
  ia.origin_country,
  ia.destination_country,
  ia.border_checkpoint,
  ia.checkpoint_out,
  ia.transport_mode,
  COUNT(i.id)::int AS item_count,
  COALESCE(SUM(i.requested_quantity),0) AS requested_quantity,
  COALESCE(SUM(COALESCE(i.cleared_packs,i.cleared_quantity,0)),0) AS total_packs,
  COALESCE(SUM(i.item_value),0) AS total_value,
  COALESCE(SUM(i.active_substance_kg),0) AS amr_kg,
  ia.status,
  ia.created_at,
  ia.updated_at
FROM trade.import_application ia
LEFT JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_application_item i ON i.application_id=ia.id
GROUP BY
  ia.id,ia.application_no,ia.permit_no,ia.import_type,ia.application_date,
  ia.decision_date,ia.cleared_date,c.legal_name_lo,c.legal_name_en,
  ia.origin_country,ia.destination_country,ia.border_checkpoint,ia.checkpoint_out,
  ia.transport_mode,ia.status,ia.created_at,ia.updated_at;

-- ---------------------------------------------------------------------------
-- 4. Regulatory hard-delete guards and updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_vet_drug_internal_memo_updated_at
  ON registration.veterinary_drug_internal_memo;
CREATE TRIGGER trg_vet_drug_internal_memo_updated_at
BEFORE UPDATE ON registration.veterinary_drug_internal_memo
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_vet_drug_internal_memo_item_updated_at
  ON registration.veterinary_drug_internal_memo_item;
CREATE TRIGGER trg_vet_drug_internal_memo_item_updated_at
BEFORE UPDATE ON registration.veterinary_drug_internal_memo_item
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_coord_requirement_updated_at
  ON lookup.regulatory_coordination_requirement;
CREATE TRIGGER trg_coord_requirement_updated_at
BEFORE UPDATE ON lookup.regulatory_coordination_requirement
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_trade_coord_sheet_updated_at
  ON trade.application_coordination_sheet;
CREATE TRIGGER trg_trade_coord_sheet_updated_at
BEFORE UPDATE ON trade.application_coordination_sheet
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_trade_coord_item_updated_at
  ON trade.application_coordination_item;
CREATE TRIGGER trg_trade_coord_item_updated_at
BEFORE UPDATE ON trade.application_coordination_item
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_internal_memo
  ON registration.veterinary_drug_internal_memo;
CREATE TRIGGER trg_no_delete_vet_drug_internal_memo
BEFORE DELETE ON registration.veterinary_drug_internal_memo
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_internal_memo_item
  ON registration.veterinary_drug_internal_memo_item;
CREATE TRIGGER trg_no_delete_vet_drug_internal_memo_item
BEFORE DELETE ON registration.veterinary_drug_internal_memo_item
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_coord_requirement
  ON lookup.regulatory_coordination_requirement;
CREATE TRIGGER trg_no_delete_coord_requirement
BEFORE DELETE ON lookup.regulatory_coordination_requirement
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_trade_coord_sheet
  ON trade.application_coordination_sheet;
CREATE TRIGGER trg_no_delete_trade_coord_sheet
BEFORE DELETE ON trade.application_coordination_sheet
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_trade_coord_item
  ON trade.application_coordination_item;
CREATE TRIGGER trg_no_delete_trade_coord_item
BEFORE DELETE ON trade.application_coordination_item
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE registration.veterinary_drug_internal_memo IS
'One official/internal coordination memo may cover many veterinary drug registrations. It is a cover/acknowledgement sheet, not the registration certificate itself.';
COMMENT ON TABLE registration.veterinary_drug_internal_memo_item IS
'One memo row per product/registration profile. Selected package/presentation sub-registrations are grouped and snapshotted inside selected_presentations.';
COMMENT ON TABLE trade.application_coordination_sheet IS
'Persistent LVSP version of the legacy import/export/transit coordination review sheet for veterinary drugs/devices.';
COMMENT ON VIEW analytics.v_veterinary_drug_registry_report IS
'Stable source for the shared regulatory report builder: veterinary drug registration.';
COMMENT ON VIEW analytics.v_veterinary_trade_permit_report IS
'Stable source for the shared regulatory report builder: veterinary trade applications/permits.';
