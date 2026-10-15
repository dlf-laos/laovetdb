CREATE TABLE disease.disease (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 scientific_name TEXT, disease_category VARCHAR(100), zoonotic BOOLEAN NOT NULL DEFAULT FALSE, aquatic BOOLEAN NOT NULL DEFAULT FALSE,
 notifiable_status VARCHAR(50), is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TRIGGER trg_disease_updated_at BEFORE UPDATE ON disease.disease FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
