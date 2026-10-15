CREATE TABLE enforcement.enforcement_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_no VARCHAR(120) NOT NULL UNIQUE,
 source_inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, regulated_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', opened_at TIMESTAMPTZ NOT NULL DEFAULT now(), closed_at TIMESTAMPTZ);
CREATE TABLE enforcement.enforcement_case_violation (enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 violation_id UUID NOT NULL REFERENCES compliance.violation(id) ON DELETE RESTRICT, PRIMARY KEY(enforcement_case_id,violation_id));
CREATE TABLE enforcement.action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 action_type VARCHAR(50) NOT NULL, decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ, effective_to TIMESTAMPTZ,
 reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_enforcement_action_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE enforcement.appeal (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, appellant_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 submitted_at TIMESTAMPTZ NOT NULL, grounds TEXT, status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED', review_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT);
CREATE INDEX idx_enforcement_party ON enforcement.enforcement_case(regulated_party_id,status); CREATE INDEX idx_enforcement_facility ON enforcement.enforcement_case(facility_id,status);
