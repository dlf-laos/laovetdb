CREATE TABLE notification.template (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_code VARCHAR(100) NOT NULL, language_code VARCHAR(10) NOT NULL,
 channel VARCHAR(30) NOT NULL, subject_template TEXT, body_template TEXT NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(template_code,language_code,channel,version_no));
CREATE TABLE notification.message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_type VARCHAR(150), recipient_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 recipient_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, template_id UUID REFERENCES notification.template(id) ON DELETE RESTRICT,
 payload JSONB, status VARCHAR(30) NOT NULL DEFAULT 'QUEUED', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_notification_recipient CHECK(recipient_party_id IS NOT NULL OR recipient_user_id IS NOT NULL));
CREATE TABLE notification.delivery (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), message_id UUID NOT NULL REFERENCES notification.message(id) ON DELETE RESTRICT,
 channel VARCHAR(30) NOT NULL, destination_masked TEXT, provider_reference TEXT, attempt_no INTEGER NOT NULL DEFAULT 1 CHECK(attempt_no>0),
 attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(), delivered_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL, error_text TEXT);
CREATE INDEX idx_notification_queue ON notification.message(created_at) WHERE status='QUEUED';
