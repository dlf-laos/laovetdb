CREATE TABLE lookup.country (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), iso2_code CHAR(2) UNIQUE, iso3_code CHAR(3) UNIQUE,
 numeric_code VARCHAR(3), name_lo TEXT NOT NULL, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
