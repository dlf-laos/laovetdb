CREATE TABLE trade.operator (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 operator_no VARCHAR(120), operator_status VARCHAR(30) NOT NULL DEFAULT 'PENDING', registration_id UUID REFERENCES registration.registration(id) ON DELETE RESTRICT,
 valid_from DATE, valid_to DATE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_trade_operator_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_trade_operator_no ON trade.operator(operator_no) WHERE operator_no IS NOT NULL; CREATE INDEX idx_trade_operator_party ON trade.operator(party_id,operator_status);
CREATE TABLE trade.permit_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE trade.permit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), permit_no VARCHAR(120) NOT NULL UNIQUE,
 permit_type_id UUID NOT NULL REFERENCES trade.permit_type(id) ON DELETE RESTRICT, operator_id UUID NOT NULL REFERENCES trade.operator(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, valid_from TIMESTAMPTZ, valid_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL,
 CONSTRAINT ck_trade_permit_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_trade_permit_operator ON trade.permit(operator_id,status);
