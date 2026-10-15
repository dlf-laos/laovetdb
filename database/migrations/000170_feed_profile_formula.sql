CREATE TABLE feed.feed_profile (product_id UUID PRIMARY KEY REFERENCES product.product(id) ON DELETE RESTRICT, feed_category VARCHAR(100), intended_use TEXT,
 production_stage VARCHAR(100), medicated_feed BOOLEAN NOT NULL DEFAULT FALSE);
CREATE TABLE feed.formula (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 formula_code VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_feed_formula_code ON feed.formula(product_id,formula_code) WHERE formula_code IS NOT NULL;
CREATE TABLE feed.formula_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), formula_id UUID NOT NULL REFERENCES feed.formula(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from DATE, effective_to DATE, reason_for_change TEXT,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, source_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(formula_id,version_no), CONSTRAINT ck_formula_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE feed.formula_ingredient (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), formula_version_id UUID NOT NULL REFERENCES feed.formula_version(id) ON DELETE RESTRICT,
 ingredient_id UUID NOT NULL REFERENCES product.ingredient(id) ON DELETE RESTRICT, inclusion_value NUMERIC(18,6), inclusion_unit VARCHAR(30), notes TEXT,
 CONSTRAINT ck_formula_inclusion CHECK(inclusion_value IS NULL OR inclusion_value>=0));
CREATE INDEX idx_formula_product ON feed.formula(product_id); CREATE INDEX idx_formula_ingredient_version ON feed.formula_ingredient(formula_version_id);
