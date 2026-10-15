-- LVSP 000790: Flexible Annual Import Plan foundation
-- Additive extension of 000780. Core 000780 tables are NOT altered.

DO $$
BEGIN
  IF to_regclass('trade.import_plan') IS NULL
     OR to_regclass('trade.import_plan_item') IS NULL THEN
    RAISE EXCEPTION '000790 requires migration 000780 first';
  END IF;
END $$;

CREATE TABLE trade.import_plan_profile (
  import_plan_id uuid PRIMARY KEY REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  detail_level varchar(20) NOT NULL DEFAULT 'ITEM'
    CHECK (detail_level IN ('ITEM','CATEGORY','HYBRID')),
  movement_type varchar(20) NOT NULL DEFAULT 'IMPORT'
    CHECK (movement_type IN ('IMPORT','EXPORT','TRANSIT','RE_EXPORT')),
  service_type varchar(80) NOT NULL DEFAULT 'VET_DRUG_DEVICE',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE trade.import_plan_item_profile (
  plan_item_id uuid PRIMARY KEY REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  parent_plan_item_id uuid REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  scope_type varchar(20) NOT NULL DEFAULT 'ITEM'
    CHECK (scope_type IN ('ITEM','CATEGORY','GROUP')),
  category_code varchar(100),
  planned_value_usd numeric(20,2) CHECK (planned_value_usd IS NULL OR planned_value_usd>=0),
  planned_item_count integer CHECK (planned_item_count IS NULL OR planned_item_count>=0),
  tracking_basis varchar(30) NOT NULL DEFAULT 'QUANTITY'
    CHECK (tracking_basis IN ('QUANTITY','VALUE','QUANTITY_VALUE','COUNT_VALUE','REFERENCE_ONLY')),
  count_is_reference boolean NOT NULL DEFAULT true,
  allow_item_mapping boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (parent_plan_item_id IS NULL OR parent_plan_item_id<>plan_item_id)
);

CREATE INDEX idx_import_plan_item_profile_parent
  ON trade.import_plan_item_profile(parent_plan_item_id);
CREATE INDEX idx_import_plan_item_profile_category
  ON trade.import_plan_item_profile(category_code) WHERE category_code IS NOT NULL;

CREATE TABLE trade.import_plan_allocation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_item_id uuid NOT NULL REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  source_entity_type varchar(60) NOT NULL,
  source_entity_id uuid NOT NULL,
  allocation_stage varchar(20) NOT NULL
    CHECK (allocation_stage IN ('APPLICATION','PERMIT','CLEARANCE','ADJUSTMENT')),
  allocated_quantity numeric(20,6) CHECK (allocated_quantity IS NULL OR allocated_quantity>=0),
  source_unit varchar(40),
  allocated_value_usd numeric(20,2) CHECK (allocated_value_usd IS NULL OR allocated_value_usd>=0),
  mapping_method varchar(20) NOT NULL DEFAULT 'MANUAL'
    CHECK (mapping_method IN ('AUTO','MANUAL','IMPORTED','RULE')),
  confidence_score numeric(5,4) CHECK (confidence_score IS NULL OR confidence_score BETWEEN 0 AND 1),
  mapping_note text,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (allocated_quantity IS NOT NULL OR allocated_value_usd IS NOT NULL OR allocation_stage='ADJUSTMENT')
);

CREATE UNIQUE INDEX uq_import_plan_allocation_active_source
ON trade.import_plan_allocation(source_entity_type,source_entity_id,allocation_stage)
WHERE status='ACTIVE';
CREATE INDEX idx_import_plan_allocation_plan_item
ON trade.import_plan_allocation(plan_item_id,allocation_stage,status);

CREATE TABLE trade.import_plan_mapping_rule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_plan_id uuid NOT NULL REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  plan_item_id uuid NOT NULL REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  product_id uuid,
  registration_id uuid,
  product_name_normalized text,
  category_code varchar(100),
  priority integer NOT NULL DEFAULT 100 CHECK(priority>=0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    product_id IS NOT NULL OR registration_id IS NOT NULL
    OR NULLIF(btrim(product_name_normalized),'') IS NOT NULL
    OR category_code IS NOT NULL
  )
);

CREATE INDEX idx_import_plan_mapping_rule_plan
ON trade.import_plan_mapping_rule(import_plan_id,is_active,priority);

-- Preserve current 000780 behavior for all existing data.
INSERT INTO trade.import_plan_profile(import_plan_id,detail_level)
SELECT id,'ITEM' FROM trade.import_plan;

INSERT INTO trade.import_plan_item_profile(plan_item_id,scope_type,tracking_basis)
SELECT id,'ITEM','QUANTITY' FROM trade.import_plan_item;

-- New extension rows are regulatory records: no hard delete.
CREATE TRIGGER trg_no_delete_import_plan_profile
BEFORE DELETE ON trade.import_plan_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_item_profile
BEFORE DELETE ON trade.import_plan_item_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_allocation
BEFORE DELETE ON trade.import_plan_allocation
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_mapping_rule
BEFORE DELETE ON trade.import_plan_mapping_rule
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_import_plan_profile_updated_at
BEFORE UPDATE ON trade.import_plan_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_item_profile_updated_at
BEFORE UPDATE ON trade.import_plan_item_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_allocation_updated_at
BEFORE UPDATE ON trade.import_plan_allocation
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_mapping_rule_updated_at
BEFORE UPDATE ON trade.import_plan_mapping_rule
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
