CREATE TABLE audit.event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 actor_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, action_code VARCHAR(100) NOT NULL, resource_type VARCHAR(100), resource_id UUID,
 request_id UUID, correlation_id UUID, ip_address INET, before_data JSONB, after_data JSONB, metadata JSONB);
CREATE INDEX idx_audit_event_time ON audit.event(occurred_at DESC); CREATE INDEX idx_audit_resource ON audit.event(resource_type,resource_id);
CREATE INDEX idx_audit_correlation ON audit.event(correlation_id); CREATE INDEX idx_audit_actor ON audit.event(actor_user_id,occurred_at DESC);
