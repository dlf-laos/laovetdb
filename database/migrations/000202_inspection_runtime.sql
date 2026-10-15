CREATE TABLE inspection.inspection_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_no VARCHAR(120) NOT NULL UNIQUE,
 program_version_id UUID NOT NULL REFERENCES inspection.program_version(id) ON DELETE RESTRICT, facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, trigger_type VARCHAR(40) NOT NULL, priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
 status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', planned_date DATE, opened_at TIMESTAMPTZ NOT NULL DEFAULT now(), closed_at TIMESTAMPTZ,
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE inspection.visit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 visit_no INTEGER NOT NULL CHECK(visit_no>0), started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, location geography(Point,4326),
 offline_created BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED', UNIQUE(inspection_case_id,visit_no));
CREATE TABLE inspection.assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 inspector_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, assignment_role VARCHAR(30) NOT NULL DEFAULT 'INSPECTOR',
 assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(), conflict_declared BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'ASSIGNED');
CREATE TABLE inspection.response (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 checklist_item_id UUID NOT NULL REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT, response_code VARCHAR(100), response_text TEXT, numeric_value NUMERIC(20,6),
 answered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, answered_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(visit_id,checklist_item_id));
CREATE INDEX idx_inspection_case_facility ON inspection.inspection_case(facility_id,status); CREATE INDEX idx_inspection_assignment_user ON inspection.assignment(inspector_user_id,status);
ALTER TABLE facility.gmp_assessment ADD CONSTRAINT fk_gmp_inspection_case FOREIGN KEY(inspection_case_id) REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT;
