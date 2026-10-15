CREATE TABLE system.service_definition (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), service_code VARCHAR(50) NOT NULL UNIQUE, domain_code VARCHAR(50) NOT NULL,
 name_lo TEXT NOT NULL, name_en TEXT, description TEXT, applicant_type VARCHAR(50), is_public BOOLEAN NOT NULL DEFAULT FALSE,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE system.service_version (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), service_id UUID NOT NULL REFERENCES system.service_definition(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 workflow_code VARCHAR(100), sla_configuration JSONB, requirements JSONB, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(service_id,version_no),
 CONSTRAINT ck_service_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_service_domain ON system.service_definition(domain_code);
CREATE TRIGGER trg_service_definition_updated_at BEFORE UPDATE ON system.service_definition FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
