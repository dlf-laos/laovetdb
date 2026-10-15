CREATE TABLE gis.layer (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), layer_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 source_domain VARCHAR(50), geometry_type VARCHAR(50), is_public BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE gis.layer_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), layer_id UUID NOT NULL REFERENCES gis.layer(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, configuration JSONB,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(layer_id,version_no), CONSTRAINT ck_gis_layer_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
