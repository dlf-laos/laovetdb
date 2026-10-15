CREATE TABLE disease.amr_isolate (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT,
 organism_code VARCHAR(100) NOT NULL, isolate_code VARCHAR(120), isolation_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_amr_isolate_code ON disease.amr_isolate(isolate_code) WHERE isolate_code IS NOT NULL;
CREATE TABLE disease.amr_susceptibility (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), isolate_id UUID NOT NULL REFERENCES disease.amr_isolate(id) ON DELETE RESTRICT,
 antimicrobial_code VARCHAR(100) NOT NULL, test_method_id UUID REFERENCES laboratory.test_method(id) ON DELETE RESTRICT, numeric_value NUMERIC(20,8),
 unit_code VARCHAR(30), interpretation_code VARCHAR(30), result_version_id UUID REFERENCES laboratory.result_version(id) ON DELETE RESTRICT);
CREATE INDEX idx_amr_isolate_sample ON disease.amr_isolate(sample_id);
