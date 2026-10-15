CREATE TABLE fisheries.aquaculture_facility (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 production_system VARCHAR(100), water_source_type VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE fisheries.aquaculture_unit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES fisheries.aquaculture_facility(facility_id) ON DELETE RESTRICT,
 unit_code VARCHAR(100), unit_type VARCHAR(50) NOT NULL, capacity_value NUMERIC(20,6), capacity_unit VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_aquaculture_capacity CHECK(capacity_value IS NULL OR capacity_value>=0));
CREATE UNIQUE INDEX uq_aquaculture_unit_code ON fisheries.aquaculture_unit(facility_id,unit_code) WHERE unit_code IS NOT NULL;
