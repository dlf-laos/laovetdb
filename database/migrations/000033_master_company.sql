CREATE TABLE master.company (party_id UUID PRIMARY KEY REFERENCES master.party(id) ON DELETE RESTRICT, legal_name_lo TEXT NOT NULL,
 legal_name_en TEXT, enterprise_no VARCHAR(100), tax_no VARCHAR(100), country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 registration_date DATE, phone VARCHAR(50), email CITEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_company_enterprise_no ON master.company(enterprise_no) WHERE enterprise_no IS NOT NULL;
CREATE INDEX idx_company_name_lo_trgm ON master.company USING GIN(legal_name_lo gin_trgm_ops);
CREATE INDEX idx_company_name_en_trgm ON master.company USING GIN(legal_name_en gin_trgm_ops);
CREATE TRIGGER trg_company_updated_at BEFORE UPDATE ON master.company FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE OR REPLACE FUNCTION master.enforce_company_party_kind()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master.party p WHERE p.id = NEW.party_id AND p.party_kind = 'COMPANY') THEN
        RAISE EXCEPTION 'party_id % is not a COMPANY party', NEW.party_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_company_party_kind BEFORE INSERT OR UPDATE OF party_id ON master.company
FOR EACH ROW EXECUTE FUNCTION master.enforce_company_party_kind();
