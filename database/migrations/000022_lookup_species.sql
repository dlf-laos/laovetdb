CREATE TABLE lookup.species (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, scientific_name TEXT,
 name_lo TEXT NOT NULL, name_en TEXT, tracking_mode VARCHAR(30) NOT NULL DEFAULT 'CONFIGURABLE', is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT ck_species_tracking_mode CHECK(tracking_mode IN ('INDIVIDUAL','GROUP','BOTH','CONFIGURABLE')));
