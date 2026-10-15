CREATE TABLE registration.registration_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE registration.registration (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), registration_no VARCHAR(120) NOT NULL UNIQUE,
 registration_type_id UUID NOT NULL REFERENCES registration.registration_type(id) ON DELETE RESTRICT,
 holder_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, effective_from DATE, expiry_date DATE, status VARCHAR(30) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_registration_dates CHECK(expiry_date IS NULL OR effective_from IS NULL OR expiry_date>=effective_from));
CREATE TABLE registration.product_registration (registration_id UUID PRIMARY KEY REFERENCES registration.registration(id) ON DELETE RESTRICT,
 product_id UUID NOT NULL, registration_scope JSONB);
CREATE TABLE registration.registration_action (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), registration_id UUID NOT NULL REFERENCES registration.registration(id) ON DELETE RESTRICT,
 action_type VARCHAR(40) NOT NULL, case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_at TIMESTAMPTZ, details JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_registration_holder ON registration.registration(holder_party_id); CREATE INDEX idx_registration_expiry ON registration.registration(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_registration_action ON registration.registration_action(registration_id,created_at);
