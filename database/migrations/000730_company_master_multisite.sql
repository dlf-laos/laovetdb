-- LVSP v0.8.0 — Company Master + Multi-Site / Multi-Address
-- Non-destructive normalization: one legal company -> many physical sites/addresses.

CREATE TABLE IF NOT EXISTS lookup.company_site_role (
  code VARCHAR(60) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
INSERT INTO lookup.company_site_role(code,name_lo,name_en,is_active) VALUES
('REGISTERED_OFFICE','ທີ່ຢູ່ຈົດທະບຽນ','Registered office',TRUE),
('HEAD_OFFICE','ສຳນັກງານໃຫຍ່','Head office',TRUE),
('BUSINESS_SITE','ສະຖານທີ່ດຳເນີນທຸລະກິດ','Business site',TRUE),
('BRANCH_OFFICE','ສາຂາ','Branch office',TRUE),
('REGISTRATION_HOLDER_OFFICE','ສຳນັກງານຜູ້ຖືທະບຽນ','Registration holder office',TRUE),
('IMPORTER_OFFICE','ສຳນັກງານຜູ້ນຳເຂົ້າ','Importer office',TRUE),
('MANUFACTURING_SITE','ໂຮງງານ/ສະຖານທີ່ຜະລິດ','Manufacturing site',TRUE),
('WAREHOUSE','ສາງ','Warehouse',TRUE),
('DISTRIBUTION_SITE','ສະຖານທີ່ຈັດຈຳໜ່າຍ','Distribution site',TRUE),
('OTHER','ສະຖານທີ່ອື່ນ','Other site',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO lookup.facility_type(code,name_lo,name_en,is_active) VALUES
('REGISTERED_OFFICE','ສຳນັກງານຈົດທະບຽນ','Registered Office',TRUE),
('HEAD_OFFICE','ສຳນັກງານໃຫຍ່','Head Office',TRUE),
('BUSINESS_SITE','ສະຖານທີ່ດຳເນີນທຸລະກິດ','Business Site',TRUE),
('BRANCH_OFFICE','ສຳນັກງານສາຂາ','Branch Office',TRUE),
('REGISTRATION_HOLDER_OFFICE','ສຳນັກງານຜູ້ຖືທະບຽນ','Registration Holder Office',TRUE),
('IMPORTER_OFFICE','ສຳນັກງານຜູ້ນຳເຂົ້າ','Importer Office',TRUE),
('MANUFACTURING_SITE','ໂຮງງານ/ສະຖານທີ່ຜະລິດ','Manufacturing Site',TRUE),
('DISTRIBUTION_SITE','ສະຖານທີ່ຈັດຈຳໜ່າຍ','Distribution Site',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;


INSERT INTO master.party_role_type(code,name_lo,name_en,allowed_party_kind,is_active) VALUES
('REGISTRATION_HOLDER','ຜູ້ຖືທະບຽນ','Registration Holder','COMPANY',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,allowed_party_kind=EXCLUDED.allowed_party_kind,is_active=TRUE;

ALTER TABLE master.company ADD COLUMN IF NOT EXISTS website TEXT;

CREATE TABLE IF NOT EXISTS master.company_alias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  alias_name TEXT NOT NULL,
  alias_type VARCHAR(40) NOT NULL DEFAULT 'LEGACY_NAME',
  source_system VARCHAR(80),
  valid_from DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(company_id,alias_name)
);
CREATE INDEX IF NOT EXISTS idx_company_alias_name_trgm ON master.company_alias USING GIN(alias_name gin_trgm_ops);

CREATE TABLE IF NOT EXISTS master.company_site (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
  site_role_code VARCHAR(60) NOT NULL REFERENCES lookup.company_site_role(code) ON DELETE RESTRICT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  notes TEXT,
  source_system VARCHAR(80),
  source_record_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_company_site_dates CHECK(valid_to IS NULL OR valid_to>=valid_from),
  UNIQUE(company_id,facility_id,site_role_code)
);
CREATE INDEX IF NOT EXISTS idx_company_site_company ON master.company_site(company_id,status);
CREATE INDEX IF NOT EXISTS idx_company_site_facility ON master.company_site(facility_id,status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_company_site_primary_role ON master.company_site(company_id,site_role_code) WHERE is_primary=TRUE AND status='ACTIVE';
CREATE TRIGGER trg_company_site_updated_at BEFORE UPDATE ON master.company_site FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS master.facility_contact (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
  contact_type VARCHAR(30) NOT NULL CHECK(contact_type IN ('PHONE','EMAIL','WEBSITE','FAX','OTHER')),
  contact_value TEXT NOT NULL,
  label TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_facility_contact_dates CHECK(valid_to IS NULL OR valid_to>=valid_from)
);
CREATE INDEX IF NOT EXISTS idx_facility_contact_facility ON master.facility_contact(facility_id,status);

CREATE TABLE IF NOT EXISTS master.company_external_registration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  registration_type VARCHAR(60) NOT NULL,
  registration_no VARCHAR(150) NOT NULL,
  facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  issuing_authority TEXT,
  issue_date DATE,
  expiry_date DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  notes TEXT,
  source_system VARCHAR(80),
  source_record_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(company_id,registration_type,registration_no)
);
CREATE INDEX IF NOT EXISTS idx_company_external_registration ON master.company_external_registration(company_id,status,expiry_date);
CREATE TRIGGER trg_company_extreg_updated_at BEFORE UPDATE ON master.company_external_registration FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS holder_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS importer_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS manufacturer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS manufacturer_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS distributor_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS distributor_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS holder_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS holder_address_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS importer_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS importer_address_snapshot TEXT;

-- The master links are live/current. Snapshot columns preserve the regulatory text as it was at approval/issuance.
-- Issued certificates must not silently change because a company later moves or changes its current contact details.

ALTER TABLE trade.import_plan ADD COLUMN IF NOT EXISTS company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;
ALTER TABLE trade.import_application ADD COLUMN IF NOT EXISTS company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;

-- Keep old records valid. No automatic merge of possibly duplicate legal entities is performed.
