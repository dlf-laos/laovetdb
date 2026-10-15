CREATE TABLE master.facility (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_no VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, address_text_lo TEXT, address_text_en TEXT,
 location geography(Point,4326), status VARCHAR(30) NOT NULL DEFAULT 'PROPOSED', established_date DATE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID);
CREATE UNIQUE INDEX uq_facility_no ON master.facility(facility_no) WHERE facility_no IS NOT NULL;
CREATE INDEX idx_facility_admin_unit ON master.facility(admin_unit_id); CREATE INDEX idx_facility_location ON master.facility USING GIST(location);
CREATE INDEX idx_facility_name_lo_trgm ON master.facility USING GIN(name_lo gin_trgm_ops);
CREATE TRIGGER trg_facility_updated_at BEFORE UPDATE ON master.facility FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
CREATE TABLE master.facility_type_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 facility_type_id UUID NOT NULL REFERENCES lookup.facility_type(id) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_facility_type_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE TABLE master.facility_party_role (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, role_code VARCHAR(50) NOT NULL REFERENCES master.party_role_type(code) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_facility_party_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_facility_type_assignment ON master.facility_type_assignment(facility_id,status);
CREATE INDEX idx_facility_party_role ON master.facility_party_role(facility_id,role_code,status);
