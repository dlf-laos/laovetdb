CREATE TABLE workflow.instance (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE RESTRICT,
 service_id UUID REFERENCES system.service_definition(id) ON DELETE RESTRICT, business_entity_type VARCHAR(100) NOT NULL, business_entity_id UUID NOT NULL,
 current_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL, started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 completed_at TIMESTAMPTZ, started_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE TABLE workflow.task (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_instance_id UUID NOT NULL REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 step_id UUID NOT NULL REFERENCES workflow.step(id) ON DELETE RESTRICT, assigned_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 assigned_role_id UUID REFERENCES security.role(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', due_at TIMESTAMPTZ,
 completed_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE workflow.action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_instance_id UUID NOT NULL REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 task_id UUID REFERENCES workflow.task(id) ON DELETE RESTRICT, action_code VARCHAR(100) NOT NULL,
 from_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT, to_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT,
 actor_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, comment TEXT, performed_at TIMESTAMPTZ NOT NULL DEFAULT now(), metadata JSONB);
CREATE INDEX idx_workflow_task_user_status ON workflow.task(assigned_user_id,status);
CREATE INDEX idx_workflow_task_due ON workflow.task(due_at) WHERE status='OPEN';
CREATE INDEX idx_workflow_action_instance_time ON workflow.action(workflow_instance_id,performed_at);
