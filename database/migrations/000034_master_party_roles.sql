CREATE TABLE master.party_role_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(50) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, allowed_party_kind VARCHAR(20), is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT ck_role_party_kind CHECK(allowed_party_kind IS NULL OR allowed_party_kind IN ('PERSON','COMPANY')));
CREATE TABLE master.party_role_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 role_type_id UUID NOT NULL REFERENCES master.party_role_type(id) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_party_role_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_party_role_party ON master.party_role_assignment(party_id,status);
CREATE INDEX idx_party_role_type ON master.party_role_assignment(role_type_id,status);
