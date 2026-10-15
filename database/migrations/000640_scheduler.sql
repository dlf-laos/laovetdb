CREATE TABLE system.scheduled_job (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), job_code VARCHAR(100) NOT NULL UNIQUE, job_type VARCHAR(50) NOT NULL,
 schedule_expression TEXT, configuration JSONB, is_enabled BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE system.scheduled_job_execution (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), job_id UUID NOT NULL REFERENCES system.scheduled_job(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ NOT NULL, finished_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL, error_text TEXT, metrics JSONB);
CREATE INDEX idx_job_execution_time ON system.scheduled_job_execution(job_id,started_at DESC);
