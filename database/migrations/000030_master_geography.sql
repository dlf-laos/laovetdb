CREATE TABLE master.admin_unit (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), parent_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 admin_unit_type_id UUID NOT NULL REFERENCES lookup.admin_unit_type(id) ON DELETE RESTRICT,
 country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, official_code VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT,
 valid_from DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', geometry geometry(MultiPolygon,4326),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID,
 CONSTRAINT ck_admin_unit_validity CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_admin_unit_code ON master.admin_unit(official_code) WHERE official_code IS NOT NULL;
CREATE INDEX idx_admin_unit_parent ON master.admin_unit(parent_id); CREATE INDEX idx_admin_unit_type ON master.admin_unit(admin_unit_type_id);
CREATE INDEX idx_admin_unit_geometry ON master.admin_unit USING GIST(geometry);
CREATE INDEX idx_admin_unit_name_lo_trgm ON master.admin_unit USING GIN(name_lo gin_trgm_ops);
CREATE TRIGGER trg_admin_unit_updated_at BEFORE UPDATE ON master.admin_unit FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
