CREATE TABLE licensing.license_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE licensing.license (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), license_no VARCHAR(120) NOT NULL UNIQUE,
 license_type_id UUID NOT NULL REFERENCES licensing.license_type(id) ON DELETE RESTRICT,
 holder_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, effective_from DATE, expiry_date DATE, status VARCHAR(30) NOT NULL, conditions TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_license_dates CHECK(expiry_date IS NULL OR effective_from IS NULL OR expiry_date>=effective_from));
CREATE TABLE licensing.facility_license (license_id UUID PRIMARY KEY REFERENCES licensing.license(id) ON DELETE RESTRICT,
 facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT, activity_code VARCHAR(100), scope_details JSONB);
CREATE TABLE licensing.license_action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), license_id UUID NOT NULL REFERENCES licensing.license(id) ON DELETE RESTRICT,
 action_type VARCHAR(40) NOT NULL, case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_at TIMESTAMPTZ NOT NULL, reason TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_license_holder ON licensing.license(holder_party_id); CREATE INDEX idx_license_expiry ON licensing.license(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_facility_license_facility ON licensing.facility_license(facility_id);
