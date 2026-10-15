CREATE TABLE compliance.violation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 violation_code VARCHAR(100), regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, classification VARCHAR(30),
 confirmed_at TIMESTAMPTZ, confirmed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'UNDER_REVIEW');
CREATE TABLE compliance.capa (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 responsible_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, due_date DATE, submitted_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE compliance.capa_action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), capa_id UUID NOT NULL REFERENCES compliance.capa(id) ON DELETE RESTRICT,
 action_no INTEGER NOT NULL CHECK(action_no>0), action_text TEXT NOT NULL, responsible_person_party_id UUID REFERENCES master.person(party_id) ON DELETE RESTRICT,
 target_date DATE, completion_date DATE, evidence_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
 UNIQUE(capa_id,action_no));
CREATE TABLE compliance.verification (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), capa_id UUID NOT NULL REFERENCES compliance.capa(id) ON DELETE RESTRICT,
 verification_type VARCHAR(30) NOT NULL, verified_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 result VARCHAR(30) NOT NULL, comments TEXT);
CREATE INDEX idx_capa_finding ON compliance.capa(finding_id,status); CREATE INDEX idx_capa_due ON compliance.capa(due_date) WHERE status NOT IN ('CLOSED','VERIFIED');
