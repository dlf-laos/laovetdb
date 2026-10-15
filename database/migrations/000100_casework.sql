CREATE TABLE casework.regulatory_case (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_no VARCHAR(100) NOT NULL UNIQUE,
 service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
 applicant_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 workflow_instance_id UUID REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 status VARCHAR(40) NOT NULL DEFAULT 'DRAFT', priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', source_channel VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
 submitted_at TIMESTAMPTZ, received_at TIMESTAMPTZ, completed_at TIMESTAMPTZ,
 assigned_org_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_case_dates CHECK(completed_at IS NULL OR submitted_at IS NULL OR completed_at>=submitted_at));
CREATE TABLE casework.application (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL UNIQUE REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 application_type VARCHAR(50) NOT NULL, declaration_accepted BOOLEAN NOT NULL DEFAULT FALSE, declaration_at TIMESTAMPTZ,
 applicant_reference VARCHAR(150), submitted_payload JSONB, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE casework.case_party (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, role_code VARCHAR(50) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE casework.information_request (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 request_no INTEGER NOT NULL CHECK(request_no>0), requested_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), due_at TIMESTAMPTZ, subject TEXT NOT NULL, details TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'OPEN', responded_at TIMESTAMPTZ, UNIQUE(case_id,request_no));
CREATE TABLE casework.regulatory_decision (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_no VARCHAR(100), decision_type VARCHAR(50) NOT NULL, decision_date TIMESTAMPTZ NOT NULL, effective_from TIMESTAMPTZ, effective_to TIMESTAMPTZ,
 regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT,
 authority_org_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 authority_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, reason TEXT, conditions TEXT,
 supersedes_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ISSUED',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_decision_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE UNIQUE INDEX uq_decision_no ON casework.regulatory_decision(decision_no) WHERE decision_no IS NOT NULL;
CREATE INDEX idx_case_applicant ON casework.regulatory_case(applicant_party_id); CREATE INDEX idx_case_status_created ON casework.regulatory_case(status,created_at DESC);
CREATE INDEX idx_case_service ON casework.regulatory_case(service_version_id); CREATE INDEX idx_decision_case ON casework.regulatory_decision(case_id,decision_date DESC);
CREATE TRIGGER trg_regulatory_case_updated_at BEFORE UPDATE ON casework.regulatory_case FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
