CREATE TABLE master.facility_component (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 parent_component_id UUID REFERENCES master.facility_component(id) ON DELETE RESTRICT, component_type VARCHAR(50) NOT NULL,
 component_code VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_facility_component_code ON master.facility_component(facility_id,component_code) WHERE component_code IS NOT NULL;
CREATE INDEX idx_facility_component_facility ON master.facility_component(facility_id);
