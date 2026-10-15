CREATE TABLE facility.establishment_application (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL UNIQUE REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 proposed_facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT, establishment_type VARCHAR(100) NOT NULL,
 proposed_capacity TEXT, technical_summary TEXT, status VARCHAR(30) NOT NULL DEFAULT 'UNDER_REVIEW', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE facility.external_approval (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 approval_type VARCHAR(100) NOT NULL, issuing_agency TEXT, reference_no VARCHAR(150), issue_date DATE, expiry_date DATE,
 document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, verification_status VARCHAR(30) NOT NULL DEFAULT 'UNVERIFIED',
 verified_at TIMESTAMPTZ, verified_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_external_approval_dates CHECK(expiry_date IS NULL OR issue_date IS NULL OR expiry_date>=issue_date));
CREATE INDEX idx_establishment_facility ON facility.establishment_application(proposed_facility_id); CREATE INDEX idx_external_approval_facility ON facility.external_approval(facility_id,approval_type);
