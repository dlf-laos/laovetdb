CREATE TABLE security.role (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 is_system_role BOOLEAN NOT NULL DEFAULT FALSE, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE security.permission (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(150) NOT NULL UNIQUE, description TEXT);
CREATE TABLE security.role_permission (role_id UUID NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
 permission_id UUID NOT NULL REFERENCES security.permission(id) ON DELETE CASCADE, PRIMARY KEY(role_id,permission_id));
