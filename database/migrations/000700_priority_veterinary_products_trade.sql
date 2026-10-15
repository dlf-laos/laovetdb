-- LVSP Priority Veterinary Products Pack v0.4.0
-- Operational records for veterinary drug registration, veterinary devices,
-- annual import plans, and mixed-item import applications.

CREATE TABLE IF NOT EXISTS product.product_regulatory_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL UNIQUE REFERENCES product.product(id) ON DELETE RESTRICT,
  registration_no VARCHAR(120) UNIQUE,
  registration_type VARCHAR(40) NOT NULL DEFAULT 'IMPORT',
  trade_name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  dosage_form TEXT,
  registration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  application_no VARCHAR(120),
  application_date DATE,
  dlf_no VARCHAR(120),
  dlf_date DATE,
  issue_date DATE,
  expiry_date DATE,
  holder_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  importer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  target_species TEXT,
  active_ingredients TEXT,
  route TEXT,
  contraindications TEXT,
  warnings TEXT,
  gmp_reference TEXT,
  cpp_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_product_reg_profile_dates CHECK(expiry_date IS NULL OR issue_date IS NULL OR expiry_date >= issue_date)
);
CREATE INDEX IF NOT EXISTS idx_product_reg_profile_status ON product.product_regulatory_profile(registration_status,expiry_date);
CREATE INDEX IF NOT EXISTS idx_product_reg_profile_holder ON product.product_regulatory_profile(holder_company_id);
CREATE TRIGGER trg_product_regulatory_profile_updated_at BEFORE UPDATE ON product.product_regulatory_profile FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS product.veterinary_device (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_code VARCHAR(120) UNIQUE,
  device_name TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  device_category TEXT,
  intended_use TEXT,
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  importer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  registration_no VARCHAR(120),
  authorization_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  technical_specification TEXT,
  serial_tracking BOOLEAN NOT NULL DEFAULT FALSE,
  shelf_life TEXT,
  storage_conditions TEXT,
  instructions_for_use TEXT,
  certificate_references TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_veterinary_device_status ON product.veterinary_device(authorization_status);
CREATE INDEX IF NOT EXISTS idx_veterinary_device_importer ON product.veterinary_device(importer_company_id);
CREATE TRIGGER trg_veterinary_device_updated_at BEFORE UPDATE ON product.veterinary_device FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_no VARCHAR(120) NOT NULL UNIQUE,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  plan_year INTEGER NOT NULL CHECK(plan_year BETWEEN 2000 AND 2200),
  application_date DATE,
  approval_no VARCHAR(120),
  approval_date DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_plan_company_year ON trade.import_plan(company_id,plan_year,status);
CREATE TRIGGER trg_import_plan_updated_at BEFORE UPDATE ON trade.import_plan FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_plan_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES trade.import_plan(id) ON DELETE CASCADE,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_type VARCHAR(40) NOT NULL CHECK(item_type IN ('MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT')),
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  planned_quantity NUMERIC(18,3) NOT NULL DEFAULT 0 CHECK(planned_quantity >= 0),
  unit_code VARCHAR(40),
  planned_value NUMERIC(18,2) CHECK(planned_value IS NULL OR planned_value >= 0),
  currency_code VARCHAR(10) DEFAULT 'USD',
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id,item_no),
  CONSTRAINT ck_import_plan_item_ref CHECK (NOT (product_id IS NOT NULL AND device_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_plan ON trade.import_plan_item(plan_id,item_type);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_product ON trade.import_plan_item(product_id) WHERE product_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS trade.import_application (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_no VARCHAR(120) NOT NULL UNIQUE,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  plan_id UUID REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  application_date DATE NOT NULL DEFAULT current_date,
  import_type VARCHAR(30) NOT NULL DEFAULT 'IMPORT',
  border_checkpoint TEXT,
  invoice_no VARCHAR(120),
  invoice_date DATE,
  origin_country TEXT,
  transport_information TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  decision_no VARCHAR(120),
  decision_date DATE,
  permit_no VARCHAR(120),
  permit_valid_to DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_application_company ON trade.import_application(company_id,status,application_date);
CREATE INDEX IF NOT EXISTS idx_import_application_plan ON trade.import_application(plan_id) WHERE plan_id IS NOT NULL;
CREATE TRIGGER trg_import_application_updated_at BEFORE UPDATE ON trade.import_application FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_application_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES trade.import_application(id) ON DELETE CASCADE,
  plan_item_id UUID REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_type VARCHAR(40) NOT NULL CHECK(item_type IN ('MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT')),
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  requested_quantity NUMERIC(18,3) NOT NULL DEFAULT 0 CHECK(requested_quantity >= 0),
  approved_quantity NUMERIC(18,3) CHECK(approved_quantity IS NULL OR approved_quantity >= 0),
  cleared_quantity NUMERIC(18,3) CHECK(cleared_quantity IS NULL OR cleared_quantity >= 0),
  unit_code VARCHAR(40),
  item_value NUMERIC(18,2) CHECK(item_value IS NULL OR item_value >= 0),
  currency_code VARCHAR(10) DEFAULT 'USD',
  eligibility_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  eligibility_message TEXT,
  antimicrobial BOOLEAN NOT NULL DEFAULT FALSE,
  active_substance_kg NUMERIC(18,6) CHECK(active_substance_kg IS NULL OR active_substance_kg >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(application_id,item_no),
  CONSTRAINT ck_import_application_item_ref CHECK (NOT (product_id IS NOT NULL AND device_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_import_app_item_application ON trade.import_application_item(application_id,item_type);
CREATE INDEX IF NOT EXISTS idx_import_app_item_product ON trade.import_application_item(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_import_app_item_device ON trade.import_application_item(device_id) WHERE device_id IS NOT NULL;
