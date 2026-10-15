CREATE TABLE security.access_scope (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, domain_code VARCHAR(100), is_global BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_scope_target CHECK(is_global OR organization_id IS NOT NULL OR admin_unit_id IS NOT NULL OR domain_code IS NOT NULL));
CREATE TABLE security.user_role_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT,
 role_id UUID NOT NULL REFERENCES security.role(id) ON DELETE RESTRICT, access_scope_id UUID REFERENCES security.access_scope(id) ON DELETE RESTRICT,
 valid_from TIMESTAMPTZ NOT NULL DEFAULT now(), valid_to TIMESTAMPTZ, assigned_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_user_role_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE TABLE security.delegation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), delegator_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT,
 delegate_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, role_id UUID REFERENCES security.role(id) ON DELETE RESTRICT,
 access_scope_id UUID REFERENCES security.access_scope(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ NOT NULL,
 authority_reference TEXT, reason TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_delegation_time CHECK(effective_to>effective_from), CONSTRAINT ck_delegation_users CHECK(delegator_user_id<>delegate_user_id));
CREATE INDEX idx_user_role_user ON security.user_role_assignment(user_id,status,valid_to);
CREATE INDEX idx_delegation_delegate ON security.delegation(delegate_user_id,status,effective_to);
