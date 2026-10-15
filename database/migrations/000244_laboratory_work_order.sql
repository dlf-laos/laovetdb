CREATE TABLE laboratory.test_request (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), request_no VARCHAR(120) NOT NULL UNIQUE,
 sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT, requested_by_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 priority VARCHAR(20) NOT NULL DEFAULT 'ROUTINE', requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED');
CREATE TABLE laboratory.work_order (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), test_request_id UUID NOT NULL REFERENCES laboratory.test_request(id) ON DELETE RESTRICT,
 method_id UUID NOT NULL REFERENCES laboratory.test_method(id) ON DELETE RESTRICT, assigned_analyst_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'QUEUED');
CREATE INDEX idx_work_order_analyst_status ON laboratory.work_order(assigned_analyst_id,status);
