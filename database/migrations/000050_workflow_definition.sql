CREATE TABLE workflow.definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE workflow.definition_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), definition_id UUID NOT NULL REFERENCES workflow.definition(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(definition_id,version_no), CONSTRAINT ck_workflow_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE workflow.step (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE CASCADE,
 step_code VARCHAR(100) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT, step_type VARCHAR(50) NOT NULL, sequence_no INTEGER, configuration JSONB,
 UNIQUE(workflow_version_id,step_code));
CREATE TABLE workflow.transition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE CASCADE,
 transition_code VARCHAR(100) NOT NULL, from_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT,
 to_step_id UUID NOT NULL REFERENCES workflow.step(id) ON DELETE RESTRICT, required_permission VARCHAR(150), rule_configuration JSONB,
 UNIQUE(workflow_version_id,transition_code));
