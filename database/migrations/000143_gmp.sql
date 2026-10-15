CREATE TABLE facility.gmp_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 inspection_case_id UUID, assessment_type VARCHAR(50) NOT NULL, standard_reference TEXT, assessment_date DATE, result VARCHAR(30),
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE facility.gmp_scope (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), gmp_assessment_id UUID NOT NULL REFERENCES facility.gmp_assessment(id) ON DELETE RESTRICT,
 production_line_id UUID REFERENCES facility.production_line(id) ON DELETE RESTRICT, scope_code VARCHAR(100), scope_description TEXT);
CREATE INDEX idx_gmp_facility ON facility.gmp_assessment(facility_id,status);
