CREATE TABLE facility.production_line (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 component_id UUID REFERENCES master.facility_component(id) ON DELETE RESTRICT, line_code VARCHAR(100), line_type VARCHAR(100) NOT NULL,
 name_lo TEXT, name_en TEXT, commissioned_at DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_production_line_code ON facility.production_line(facility_id,line_code) WHERE line_code IS NOT NULL;
CREATE INDEX idx_production_line_facility ON facility.production_line(facility_id,status);
