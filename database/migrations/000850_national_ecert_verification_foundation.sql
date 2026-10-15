-- LVSP 000850 — National e-Cert & Public Verification Foundation
-- Additive only. Existing regulatory records are not changed.
CREATE SCHEMA IF NOT EXISTS certification;

CREATE TABLE IF NOT EXISTS certification.ecert_document (
  ecert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  certificate_no TEXT NOT NULL UNIQUE,
  verification_code TEXT NOT NULL UNIQUE,
  document_type_code TEXT NOT NULL,
  source_module_code TEXT NOT NULL,
  source_record_type TEXT,
  source_record_id TEXT,
  case_reference_no TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN (
    'DRAFT','UNDER_REVIEW','APPROVED','ISSUED','SENT','RECEIVED','ACCEPTED',
    'REPLACEMENT_REQUESTED','REPLACED','REJECTED','CANCELLED','EXPIRED')),
  standard_profile TEXT NOT NULL DEFAULT 'UNCEFACT_ECERT',
  standard_version TEXT,
  issue_date TIMESTAMPTZ,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  issuer_scope_type TEXT CHECK (issuer_scope_type IS NULL OR issuer_scope_type IN ('CENTRAL','PROVINCE','DISTRICT','CHECKPOINT','OTHER')),
  issuer_scope_id TEXT,
  issuer_public_name TEXT,
  issuer_office_code TEXT,
  signatory_name_snapshot TEXT,
  signatory_title_snapshot TEXT,
  origin_country_code TEXT,
  destination_country_code TEXT,
  entry_checkpoint_code TEXT,
  exit_checkpoint_code TEXT,
  subject_summary TEXT,
  public_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  structured_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  payload_xml TEXT,
  payload_hash TEXT,
  qr_target_path TEXT,
  previous_ecert_id UUID REFERENCES certification.ecert_document(ecert_id),
  replacement_reason TEXT,
  paper_fallback_allowed BOOLEAN NOT NULL DEFAULT TRUE,
  electronically_signed BOOLEAN NOT NULL DEFAULT FALSE,
  created_by_user_id TEXT,
  issued_by_user_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_document_status ON certification.ecert_document(status);
CREATE INDEX IF NOT EXISTS idx_ecert_document_module ON certification.ecert_document(source_module_code);
CREATE INDEX IF NOT EXISTS idx_ecert_document_case ON certification.ecert_document(case_reference_no);
CREATE INDEX IF NOT EXISTS idx_ecert_document_valid_until ON certification.ecert_document(valid_until);

CREATE TABLE IF NOT EXISTS certification.ecert_status_history (
  history_id BIGSERIAL PRIMARY KEY,
  ecert_id UUID NOT NULL REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  from_status TEXT,
  to_status TEXT NOT NULL,
  reason TEXT,
  actor_user_id TEXT,
  actor_scope_type TEXT,
  actor_scope_id TEXT,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_status_history_ecert ON certification.ecert_status_history(ecert_id,event_at DESC);

CREATE TABLE IF NOT EXISTS certification.ecert_acknowledgement (
  acknowledgement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ecert_id UUID NOT NULL REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  acknowledgement_code TEXT NOT NULL CHECK (acknowledgement_code IN ('RECEIVED','ACCEPTED','REPLACEMENT_REQUESTED','REJECTED')),
  channel TEXT NOT NULL DEFAULT 'WEB' CHECK (channel IN ('WEB','API','G2G','MANUAL')),
  partner_country_code TEXT,
  partner_system_name TEXT,
  partner_message_id TEXT,
  remarks TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_ack_ecert ON certification.ecert_acknowledgement(ecert_id,acknowledged_at DESC);

CREATE TABLE IF NOT EXISTS certification.ecert_exchange_message (
  exchange_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ecert_id UUID REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  direction TEXT NOT NULL CHECK (direction IN ('OUTBOUND','INBOUND')),
  message_type TEXT NOT NULL CHECK (message_type IN ('CERTIFICATE','ACKNOWLEDGEMENT','REPLACEMENT','CANCELLATION','STATUS')),
  payload_format TEXT NOT NULL DEFAULT 'JSON' CHECK (payload_format IN ('JSON','XML','PDF','XLS')),
  partner_country_code TEXT,
  partner_system_name TEXT,
  external_message_id TEXT,
  delivery_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (delivery_status IN ('PENDING','SENT','DELIVERED','FAILED','ACKNOWLEDGED')),
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  payload_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ecert_exchange_status ON certification.ecert_exchange_message(delivery_status,created_at);

CREATE TABLE IF NOT EXISTS certification.ecert_verification_event (
  verification_event_id BIGSERIAL PRIMARY KEY,
  ecert_id UUID REFERENCES certification.ecert_document(ecert_id) ON DELETE SET NULL,
  query_kind TEXT NOT NULL DEFAULT 'PUBLIC_WEB' CHECK (query_kind IN ('PUBLIC_WEB','QR','API','G2G','INTERNAL')),
  query_fingerprint TEXT,
  result_code TEXT NOT NULL CHECK (result_code IN ('VALID','EXPIRED','CANCELLED','REPLACED','REJECTED','NOT_FOUND','NOT_PUBLIC')),
  requester_country_code TEXT,
  requester_system_name TEXT,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS certification.ecert_module_policy (
  module_code TEXT NOT NULL,
  document_type_code TEXT NOT NULL,
  lifecycle_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  public_verification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  g2g_exchange_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  electronic_only_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  paper_fallback_allowed BOOLEAN NOT NULL DEFAULT TRUE,
  issuing_authority_scope_rule TEXT,
  approval_role_code TEXT,
  standard_profile TEXT NOT NULL DEFAULT 'UNCEFACT_ECERT',
  configuration_status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED')),
  notes TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (module_code,document_type_code)
);
COMMENT ON TABLE certification.ecert_module_policy IS 'Controlled configuration. Legal issuing authority is deliberately not hard-coded by migration.';

CREATE OR REPLACE VIEW certification.v_public_ecert_verification AS
SELECT d.certificate_no,d.verification_code,d.document_type_code,d.source_module_code,d.case_reference_no,
  CASE WHEN d.status='CANCELLED' THEN 'CANCELLED'
       WHEN d.status='REPLACED' THEN 'REPLACED'
       WHEN d.status='REJECTED' THEN 'REJECTED'
       WHEN d.status NOT IN ('ISSUED','SENT','RECEIVED','ACCEPTED') THEN 'NOT_PUBLIC'
       WHEN d.valid_until IS NOT NULL AND d.valid_until<now() THEN 'EXPIRED'
       ELSE 'VALID' END AS verification_status,
  d.status AS lifecycle_status,d.issue_date,d.valid_from,d.valid_until,d.issuer_public_name,d.issuer_office_code,
  d.origin_country_code,d.destination_country_code,d.entry_checkpoint_code,d.exit_checkpoint_code,
  d.subject_summary,d.public_payload,d.electronically_signed,d.paper_fallback_allowed,d.previous_ecert_id
FROM certification.ecert_document d;
COMMENT ON VIEW certification.v_public_ecert_verification IS 'Public-safe e-Cert projection; confidential structured_payload and XML are excluded.';

CREATE OR REPLACE VIEW certification.v_ecert_exchange_monitor AS
SELECT d.certificate_no,d.document_type_code,d.source_module_code,d.status AS certificate_status,
 x.direction,x.message_type,x.payload_format,x.partner_country_code,x.partner_system_name,
 x.delivery_status,x.attempt_count,x.created_at,x.sent_at,x.acknowledged_at,x.last_error
FROM certification.ecert_exchange_message x LEFT JOIN certification.ecert_document d ON d.ecert_id=x.ecert_id;

CREATE OR REPLACE FUNCTION certification.verify_public_ecert(p_query TEXT)
RETURNS TABLE (
 certificate_no TEXT, verification_code TEXT, document_type_code TEXT, source_module_code TEXT,
 case_reference_no TEXT, verification_status TEXT, lifecycle_status TEXT, issue_date TIMESTAMPTZ,
 valid_from TIMESTAMPTZ, valid_until TIMESTAMPTZ, issuer_public_name TEXT, origin_country_code TEXT,
 destination_country_code TEXT, subject_summary TEXT, public_payload JSONB,
 electronically_signed BOOLEAN, paper_fallback_allowed BOOLEAN)
LANGUAGE sql STABLE AS $$
 SELECT v.certificate_no,v.verification_code,v.document_type_code,v.source_module_code,v.case_reference_no,
 v.verification_status,v.lifecycle_status,v.issue_date,v.valid_from,v.valid_until,v.issuer_public_name,
 v.origin_country_code,v.destination_country_code,v.subject_summary,v.public_payload,
 v.electronically_signed,v.paper_fallback_allowed
 FROM certification.v_public_ecert_verification v
 WHERE lower(v.certificate_no)=lower(trim(p_query)) OR lower(v.verification_code)=lower(trim(p_query))
 LIMIT 10
$$;
COMMENT ON FUNCTION certification.verify_public_ecert(TEXT) IS 'Public-safe verification lookup by certificate number or verification code.';

