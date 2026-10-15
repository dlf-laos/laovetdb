CREATE TABLE system.legal_instrument (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), instrument_code VARCHAR(100), instrument_type VARCHAR(100) NOT NULL,
 title_lo TEXT NOT NULL, title_en TEXT, issuing_authority TEXT, issue_date DATE, effective_from DATE, effective_to DATE,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', source_url TEXT, verification_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
 verified_at TIMESTAMPTZ, verified_by UUID, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_legal_dates CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from));
CREATE UNIQUE INDEX uq_legal_instrument_code ON system.legal_instrument(instrument_code) WHERE instrument_code IS NOT NULL;
CREATE TABLE system.regulatory_rule (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), rule_code VARCHAR(100) NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 rule_type VARCHAR(50) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT, description TEXT,
 legal_instrument_id UUID REFERENCES system.legal_instrument(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ NOT NULL,
 effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', configuration JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID,
 UNIQUE(rule_code,version_no), CONSTRAINT ck_reg_rule_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_reg_rule_legal ON system.regulatory_rule(legal_instrument_id);
CREATE INDEX idx_reg_rule_effective ON system.regulatory_rule(rule_code,effective_from,effective_to);
CREATE TRIGGER trg_legal_instrument_updated_at BEFORE UPDATE ON system.legal_instrument FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
