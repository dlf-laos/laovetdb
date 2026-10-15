CREATE TABLE document.certificate (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), certificate_no VARCHAR(120) NOT NULL UNIQUE, certificate_type VARCHAR(100) NOT NULL,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 template_version_id UUID REFERENCES document.template_version(id) ON DELETE RESTRICT, issued_at TIMESTAMPTZ NOT NULL,
 valid_from TIMESTAMPTZ, valid_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL, verification_token VARCHAR(160) UNIQUE,
 generated_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 supersedes_certificate_id UUID REFERENCES document.certificate(id) ON DELETE RESTRICT,
 revoked_by_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_certificate_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_certificate_status_validity ON document.certificate(status,valid_to); CREATE INDEX idx_certificate_case ON document.certificate(source_case_id);
