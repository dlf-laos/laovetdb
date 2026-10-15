CREATE TABLE lookup.facility_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
