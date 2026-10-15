CREATE TABLE master.person (party_id UUID PRIMARY KEY REFERENCES master.party(id) ON DELETE RESTRICT, first_name_lo TEXT, last_name_lo TEXT,
 first_name_en TEXT, last_name_en TEXT, date_of_birth DATE, phone VARCHAR(50), email CITEXT,
 nationality_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_person_email ON master.person(email) WHERE email IS NOT NULL;
CREATE TRIGGER trg_person_updated_at BEFORE UPDATE ON master.person FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE OR REPLACE FUNCTION master.enforce_person_party_kind()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master.party p WHERE p.id = NEW.party_id AND p.party_kind = 'PERSON') THEN
        RAISE EXCEPTION 'party_id % is not a PERSON party', NEW.party_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_person_party_kind BEFORE INSERT OR UPDATE OF party_id ON master.person
FOR EACH ROW EXECUTE FUNCTION master.enforce_person_party_kind();
