CREATE TABLE disease.surveillance_program (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_code VARCHAR(100) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, name_lo TEXT NOT NULL, name_en TEXT, surveillance_type VARCHAR(50) NOT NULL,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE disease.surveillance_program_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_id UUID NOT NULL REFERENCES disease.surveillance_program(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from DATE NOT NULL, effective_to DATE, sampling_strategy JSONB, target_population JSONB, reporting_rules JSONB,
 status VARCHAR(30) NOT NULL, UNIQUE(program_id,version_no), CONSTRAINT ck_surveillance_dates CHECK(effective_to IS NULL OR effective_to>=effective_from));
CREATE TABLE disease.surveillance_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), surveillance_no VARCHAR(120) NOT NULL UNIQUE,
 program_version_id UUID REFERENCES disease.surveillance_program_version(id) ON DELETE RESTRICT, disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 observed_at TIMESTAMPTZ NOT NULL, source_type VARCHAR(50) NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'REPORTED',
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_surveillance_disease_time ON disease.surveillance_event(disease_id,observed_at DESC); CREATE INDEX idx_surveillance_admin ON disease.surveillance_event(admin_unit_id,observed_at DESC);
