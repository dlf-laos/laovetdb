CREATE TABLE master.party (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_kind VARCHAR(20) NOT NULL,
 display_name TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID,
 CONSTRAINT ck_party_kind CHECK(party_kind IN ('PERSON','COMPANY')));
CREATE INDEX idx_party_kind_status ON master.party(party_kind,status);
CREATE INDEX idx_party_display_name_trgm ON master.party USING GIN(display_name gin_trgm_ops);
CREATE TRIGGER trg_party_updated_at BEFORE UPDATE ON master.party FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
