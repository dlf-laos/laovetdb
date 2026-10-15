CREATE TABLE system.data_quality_issue (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, entity_id UUID,
 issue_type VARCHAR(100) NOT NULL, severity VARCHAR(30), description TEXT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
 detected_at TIMESTAMPTZ NOT NULL DEFAULT now(), resolved_at TIMESTAMPTZ);
CREATE TABLE system.data_merge_request (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, source_entity_id UUID NOT NULL,
 target_entity_id UUID NOT NULL, requested_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 reviewed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, reviewed_at TIMESTAMPTZ, decision VARCHAR(30), reason TEXT, status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
 CONSTRAINT ck_merge_distinct CHECK(source_entity_id<>target_entity_id));
CREATE INDEX idx_data_quality_open ON system.data_quality_issue(entity_type,issue_type,detected_at) WHERE status='OPEN';
