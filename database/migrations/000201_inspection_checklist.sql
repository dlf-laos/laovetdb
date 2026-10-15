CREATE TABLE inspection.checklist (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE inspection.checklist_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_id UUID NOT NULL REFERENCES inspection.checklist(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL,
 UNIQUE(checklist_id,version_no), CONSTRAINT ck_checklist_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE inspection.program_checklist (program_version_id UUID NOT NULL REFERENCES inspection.program_version(id) ON DELETE RESTRICT,
 checklist_version_id UUID NOT NULL REFERENCES inspection.checklist_version(id) ON DELETE RESTRICT, is_primary BOOLEAN NOT NULL DEFAULT TRUE,
 PRIMARY KEY(program_version_id,checklist_version_id));
CREATE TABLE inspection.checklist_item (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_version_id UUID NOT NULL REFERENCES inspection.checklist_version(id) ON DELETE CASCADE,
 parent_item_id UUID REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT, item_code VARCHAR(100) NOT NULL, item_type VARCHAR(30) NOT NULL,
 requirement_text_lo TEXT, requirement_text_en TEXT, response_type VARCHAR(30), is_required BOOLEAN NOT NULL DEFAULT FALSE,
 evidence_required BOOLEAN NOT NULL DEFAULT FALSE, scoring_rule JSONB, sequence_no INTEGER NOT NULL, UNIQUE(checklist_version_id,item_code));
