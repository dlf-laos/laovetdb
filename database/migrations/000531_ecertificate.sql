CREATE TABLE trade.ecertificate_message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), certificate_id UUID NOT NULL REFERENCES document.certificate(id) ON DELETE RESTRICT,
 partner_system_id UUID, message_direction VARCHAR(10) NOT NULL CHECK(message_direction IN ('INBOUND','OUTBOUND')), message_standard VARCHAR(50), schema_version VARCHAR(50),
 external_message_id VARCHAR(200), payload JSONB, sent_received_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'PENDING');
CREATE UNIQUE INDEX uq_ecert_external_message ON trade.ecertificate_message(external_message_id) WHERE external_message_id IS NOT NULL;
