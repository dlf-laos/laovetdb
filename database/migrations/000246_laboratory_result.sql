CREATE TABLE laboratory.result (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), work_order_id UUID NOT NULL UNIQUE REFERENCES laboratory.work_order(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE laboratory.result_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), result_id UUID NOT NULL REFERENCES laboratory.result(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), result_code VARCHAR(100), result_text TEXT, numeric_value NUMERIC(20,8), unit_code VARCHAR(30), interpretation VARCHAR(100),
 entered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, entered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 validated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, validated_at TIMESTAMPTZ,
 approved_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, approved_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 supersedes_version_id UUID REFERENCES laboratory.result_version(id) ON DELETE RESTRICT, UNIQUE(result_id,version_no));
CREATE INDEX idx_result_version_status ON laboratory.result_version(result_id,status,version_no DESC);
