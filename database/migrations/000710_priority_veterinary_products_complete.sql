-- LVSP v0.5.0 Priority Veterinary Products Complete
-- Completes detailed drug registry + multi-presentation model and bulk import support.

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS dosage_group TEXT,
  ADD COLUMN IF NOT EXISTS atcvet TEXT,
  ADD COLUMN IF NOT EXISTS distribution_classification TEXT,
  ADD COLUMN IF NOT EXISTS shelf_life TEXT,
  ADD COLUMN IF NOT EXISTS storage_conditions TEXT,
  ADD COLUMN IF NOT EXISTS indications TEXT,
  ADD COLUMN IF NOT EXISTS dosage_administration TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_meat TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_milk TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_eggs TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_honey TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_aquatic TEXT,
  ADD COLUMN IF NOT EXISTS applicant_name TEXT,
  ADD COLUMN IF NOT EXISTS applicant_nationality TEXT,
  ADD COLUMN IF NOT EXISTS applicant_id_no TEXT,
  ADD COLUMN IF NOT EXISTS business_license_no TEXT,
  ADD COLUMN IF NOT EXISTS business_license_date DATE,
  ADD COLUMN IF NOT EXISTS manufacturer_address TEXT,
  ADD COLUMN IF NOT EXISTS distributor_name TEXT,
  ADD COLUMN IF NOT EXISTS distributor_country TEXT,
  ADD COLUMN IF NOT EXISTS distributor_address TEXT,
  ADD COLUMN IF NOT EXISTS origin_registration_no TEXT,
  ADD COLUMN IF NOT EXISTS origin_registration_date DATE,
  ADD COLUMN IF NOT EXISTS valid_years INTEGER;

ALTER TABLE product.package
  ADD COLUMN IF NOT EXISTS sub_code VARCHAR(30),
  ADD COLUMN IF NOT EXISTS presentation_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE';
CREATE UNIQUE INDEX IF NOT EXISTS uq_package_sub_code ON product.package(product_id,sub_code) WHERE sub_code IS NOT NULL;

ALTER TABLE product.package_version
  ADD COLUMN IF NOT EXISTS strength_text TEXT,
  ADD COLUMN IF NOT EXISTS basis_text TEXT,
  ADD COLUMN IF NOT EXISTS target_text TEXT,
  ADD COLUMN IF NOT EXISTS total_weight_text TEXT,
  ADD COLUMN IF NOT EXISTS is_kit BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS product.package_composition (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_version_id UUID NOT NULL REFERENCES product.package_version(id) ON DELETE CASCADE,
  sequence_no INTEGER NOT NULL DEFAULT 1 CHECK(sequence_no > 0),
  ingredient_name TEXT NOT NULL,
  ingredient_role VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
  quantity_text TEXT,
  unit_text TEXT,
  part_text TEXT,
  equivalence_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(package_version_id, sequence_no)
);
CREATE INDEX IF NOT EXISTS idx_package_composition_version ON product.package_composition(package_version_id);

-- Original source row / import trace helps audit bulk spreadsheet uploads.
ALTER TABLE trade.import_plan_item
  ADD COLUMN IF NOT EXISTS package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS source_file_name TEXT,
  ADD COLUMN IF NOT EXISTS source_row_no INTEGER,
  ADD COLUMN IF NOT EXISTS source_payload JSONB,
  ADD COLUMN IF NOT EXISTS validation_status VARCHAR(30) DEFAULT 'VALID',
  ADD COLUMN IF NOT EXISTS validation_message TEXT;
ALTER TABLE trade.import_application_item
  ADD COLUMN IF NOT EXISTS package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS batch_lot_no TEXT,
  ADD COLUMN IF NOT EXISTS manufacture_date DATE,
  ADD COLUMN IF NOT EXISTS expiry_date DATE,
  ADD COLUMN IF NOT EXISTS source_file_name TEXT,
  ADD COLUMN IF NOT EXISTS source_row_no INTEGER,
  ADD COLUMN IF NOT EXISTS source_payload JSONB,
  ADD COLUMN IF NOT EXISTS validation_status VARCHAR(30) DEFAULT 'VALID',
  ADD COLUMN IF NOT EXISTS validation_message TEXT;
