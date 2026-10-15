CREATE TABLE system.retention_policy (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), data_category VARCHAR(100) NOT NULL, classification VARCHAR(30),
 retention_years INTEGER CHECK(retention_years IS NULL OR retention_years>=0), archive_required BOOLEAN NOT NULL DEFAULT FALSE,
 disposal_allowed BOOLEAN NOT NULL DEFAULT FALSE, regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE system.archive_record (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, entity_id UUID NOT NULL,
 retention_policy_id UUID REFERENCES system.retention_policy(id) ON DELETE RESTRICT, archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 archived_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, archive_reference TEXT, checksum VARCHAR(64));
CREATE INDEX idx_archive_entity ON system.archive_record(entity_type,entity_id);
