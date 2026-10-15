-- LVSP v0.9.0 — Annual Import Plan operational core
-- Non-destructive extension based on the approved annual-plan workflow and legacy balance view.
-- Actual balance is calculated from cleared quantities; this migration does not deduct on permit approval.

ALTER TABLE trade.import_plan
  ADD COLUMN IF NOT EXISTS application_ref_no VARCHAR(120),
  ADD COLUMN IF NOT EXISTS application_ref_date DATE,
  ADD COLUMN IF NOT EXISTS decision_no VARCHAR(120),
  ADD COLUMN IF NOT EXISTS decision_date DATE,
  ADD COLUMN IF NOT EXISTS valid_from DATE,
  ADD COLUMN IF NOT EXISTS valid_to DATE,
  ADD COLUMN IF NOT EXISTS approved_by TEXT,
  ADD COLUMN IF NOT EXISTS approval_conditions TEXT,
  ADD COLUMN IF NOT EXISTS company_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS company_address_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS current_version_no INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT;

ALTER TABLE trade.import_plan
  ADD CONSTRAINT ck_import_plan_validity_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from);

ALTER TABLE trade.import_plan_item
  ADD COLUMN IF NOT EXISTS item_code VARCHAR(120),
  ADD COLUMN IF NOT EXISTS line_mode VARCHAR(30) NOT NULL DEFAULT 'ITEM',
  ADD COLUMN IF NOT EXISTS group_code VARCHAR(60),
  ADD COLUMN IF NOT EXISTS group_name TEXT,
  ADD COLUMN IF NOT EXISTS planned_item_count INTEGER,
  ADD COLUMN IF NOT EXISTS planned_pack_count NUMERIC(18,3),
  ADD COLUMN IF NOT EXISTS record_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE';

ALTER TABLE trade.import_plan_item
  ADD CONSTRAINT ck_import_plan_item_line_mode CHECK(line_mode IN ('ITEM','SUMMARY_GROUP')),
  ADD CONSTRAINT ck_import_plan_item_count CHECK(planned_item_count IS NULL OR planned_item_count >= 0),
  ADD CONSTRAINT ck_import_plan_pack_count CHECK(planned_pack_count IS NULL OR planned_pack_count >= 0),
  ADD CONSTRAINT ck_import_plan_item_record_status CHECK(record_status IN ('ACTIVE','RETIRED'));

-- Replace the original full-row uniqueness with active-line uniqueness so DRAFT edits can retire
-- superseded rows without hard-deleting regulatory records or breaking historical references.
ALTER TABLE trade.import_plan_item DROP CONSTRAINT IF EXISTS import_plan_item_plan_id_item_no_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_plan_item_active_no ON trade.import_plan_item(plan_id,item_no) WHERE record_status='ACTIVE';

CREATE INDEX IF NOT EXISTS idx_import_plan_item_code ON trade.import_plan_item(plan_id,item_code) WHERE item_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_import_plan_item_group ON trade.import_plan_item(plan_id,group_code) WHERE group_code IS NOT NULL;

-- Immutable approved snapshots. The current trade.import_plan/import_plan_item rows remain the operational materialization.
CREATE TABLE IF NOT EXISTS trade.import_plan_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  version_no INTEGER NOT NULL CHECK(version_no > 0),
  version_type VARCHAR(30) NOT NULL DEFAULT 'INITIAL' CHECK(version_type IN ('INITIAL','AMENDMENT','CORRECTION')),
  reason TEXT,
  status VARCHAR(30) NOT NULL,
  plan_no VARCHAR(120) NOT NULL,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  company_name_snapshot TEXT,
  company_address_snapshot TEXT,
  plan_year INTEGER NOT NULL,
  application_date DATE,
  application_ref_no VARCHAR(120),
  application_ref_date DATE,
  approval_no VARCHAR(120),
  approval_date DATE,
  decision_no VARCHAR(120),
  decision_date DATE,
  valid_from DATE,
  valid_to DATE,
  approved_by TEXT,
  approval_conditions TEXT,
  notes TEXT,
  snapshotted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id,version_no),
  CONSTRAINT ck_import_plan_version_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS idx_import_plan_version_plan ON trade.import_plan_version(plan_id,version_no DESC);

CREATE TABLE IF NOT EXISTS trade.import_plan_item_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_version_id UUID NOT NULL REFERENCES trade.import_plan_version(id) ON DELETE RESTRICT,
  source_plan_item_id UUID REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_code VARCHAR(120),
  line_mode VARCHAR(30) NOT NULL DEFAULT 'ITEM' CHECK(line_mode IN ('ITEM','SUMMARY_GROUP')),
  group_code VARCHAR(60),
  group_name TEXT,
  item_type VARCHAR(40) NOT NULL,
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  planned_quantity NUMERIC(18,3) NOT NULL DEFAULT 0,
  planned_item_count INTEGER,
  planned_pack_count NUMERIC(18,3),
  unit_code VARCHAR(40),
  planned_value NUMERIC(18,2),
  currency_code VARCHAR(10),
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  notes TEXT,
  UNIQUE(plan_version_id,item_no)
);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_version_parent ON trade.import_plan_item_version(plan_version_id,item_no);

-- Read-only balance: planned amount minus ACTUAL cleared amount linked to the annual-plan item.
-- This deliberately does not reduce the plan when an application or permit is merely approved.
CREATE OR REPLACE VIEW analytics.v_import_plan_item_balance AS
SELECT
  pi.id AS plan_item_id,
  pi.plan_id,
  pi.item_no,
  pi.item_code,
  pi.item_type,
  pi.item_name,
  pi.registration_no,
  pi.package_description,
  pi.unit_code,
  pi.planned_quantity,
  pi.planned_value,
  COALESCE(SUM(COALESCE(iai.cleared_quantity,iai.cleared_packs,0)),0)::NUMERIC(18,3) AS actual_cleared_quantity,
  (pi.planned_quantity - COALESCE(SUM(COALESCE(iai.cleared_quantity,iai.cleared_packs,0)),0))::NUMERIC(18,3) AS remaining_quantity,
  COUNT(DISTINCT CASE WHEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0) > 0 THEN iai.application_id END)::INTEGER AS clearance_count
FROM trade.import_plan_item pi
LEFT JOIN trade.import_application_item iai ON iai.plan_item_id=pi.id
WHERE pi.record_status='ACTIVE'
GROUP BY pi.id,pi.plan_id,pi.item_no,pi.item_code,pi.item_type,pi.item_name,pi.registration_no,pi.package_description,pi.unit_code,pi.planned_quantity,pi.planned_value;

-- Regulatory snapshots are history; do not hard-delete them.
CREATE TRIGGER trg_no_delete_import_plan_version BEFORE DELETE ON trade.import_plan_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_import_plan_item_version BEFORE DELETE ON trade.import_plan_item_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
