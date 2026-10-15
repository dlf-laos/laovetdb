CREATE TABLE product.product_version (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), dosage_form_code VARCHAR(100), shelf_life_value INTEGER CHECK(shelf_life_value IS NULL OR shelf_life_value>=0),
 shelf_life_unit VARCHAR(30), storage_conditions TEXT, indications TEXT, dosage_text TEXT, withdrawal_period TEXT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(product_id,version_no), CONSTRAINT ck_product_version_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE product.product_target_species (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id UUID NOT NULL REFERENCES product.product_version(id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, usage_notes TEXT, UNIQUE(product_version_id,species_id));
CREATE INDEX idx_product_version_product ON product.product_version(product_id,status);
