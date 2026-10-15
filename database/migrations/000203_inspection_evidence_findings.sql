CREATE TABLE inspection.evidence (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, evidence_type VARCHAR(40) NOT NULL, captured_at TIMESTAMPTZ,
 captured_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, location geography(Point,4326), sha256_checksum VARCHAR(64), notes TEXT);
CREATE TABLE inspection.finding (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 visit_id UUID REFERENCES inspection.visit(id) ON DELETE RESTRICT, checklist_item_id UUID REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT,
 finding_no INTEGER NOT NULL CHECK(finding_no>0), severity_code VARCHAR(30), observation TEXT NOT NULL,
 regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', due_date DATE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(inspection_case_id,finding_no));
CREATE TABLE inspection.finding_evidence (finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 evidence_id UUID NOT NULL REFERENCES inspection.evidence(id) ON DELETE RESTRICT, PRIMARY KEY(finding_id,evidence_id));
CREATE INDEX idx_finding_case_status ON inspection.finding(inspection_case_id,status);
