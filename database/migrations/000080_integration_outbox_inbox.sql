CREATE TABLE integration.outbox_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_type VARCHAR(150) NOT NULL, aggregate_type VARCHAR(100) NOT NULL,
 aggregate_id UUID NOT NULL, schema_version INTEGER NOT NULL DEFAULT 1 CHECK(schema_version>0), correlation_id UUID, payload JSONB NOT NULL,
 occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(), published_at TIMESTAMPTZ, attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count>=0), last_error TEXT);
CREATE INDEX idx_outbox_unpublished ON integration.outbox_event(occurred_at) WHERE published_at IS NULL;
CREATE TABLE integration.inbox_message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), external_message_id VARCHAR(255) NOT NULL,
 source_system VARCHAR(100) NOT NULL, message_type VARCHAR(150), received_at TIMESTAMPTZ NOT NULL DEFAULT now(), processed_at TIMESTAMPTZ,
 processing_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED', payload JSONB, UNIQUE(source_system,external_message_id));
CREATE INDEX idx_inbox_unprocessed ON integration.inbox_message(received_at) WHERE processed_at IS NULL;
