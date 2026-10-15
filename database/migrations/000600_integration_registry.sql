CREATE TABLE integration.system (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_code VARCHAR(100) NOT NULL UNIQUE, name TEXT NOT NULL,
 owner_organization TEXT, integration_type VARCHAR(50), environment VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE integration.endpoint (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_id UUID NOT NULL REFERENCES integration.system(id) ON DELETE RESTRICT,
 endpoint_code VARCHAR(100) NOT NULL, endpoint_type VARCHAR(30) NOT NULL, base_url TEXT, authentication_type VARCHAR(50), credential_reference TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(system_id,endpoint_code));
CREATE TABLE integration.mapping (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_id UUID NOT NULL REFERENCES integration.system(id) ON DELETE RESTRICT,
 mapping_code VARCHAR(100) NOT NULL, mapping_version INTEGER NOT NULL DEFAULT 1 CHECK(mapping_version>0), source_schema TEXT, target_schema TEXT,
 mapping_config JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(system_id,mapping_code,mapping_version));
ALTER TABLE trade.ecertificate_message ADD CONSTRAINT fk_ecert_partner_system FOREIGN KEY(partner_system_id) REFERENCES integration.system(id) ON DELETE RESTRICT;
