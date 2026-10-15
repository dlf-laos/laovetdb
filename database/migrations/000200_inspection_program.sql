CREATE TABLE inspection.program (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 domain_code VARCHAR(50) NOT NULL, inspection_type VARCHAR(50) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE inspection.program_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_id UUID NOT NULL REFERENCES inspection.program(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT,
 effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL, configuration JSONB, UNIQUE(program_id,version_no),
 CONSTRAINT ck_inspection_program_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
