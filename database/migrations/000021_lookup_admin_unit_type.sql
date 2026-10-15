CREATE TABLE lookup.admin_unit_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(30) NOT NULL UNIQUE,
 level_no INTEGER NOT NULL CHECK(level_no>=0), name_lo TEXT NOT NULL, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE UNIQUE INDEX uq_admin_unit_type_level ON lookup.admin_unit_type(level_no) WHERE is_active=TRUE;
