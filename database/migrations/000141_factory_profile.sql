CREATE TABLE facility.factory_profile (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 factory_category VARCHAR(100) NOT NULL, commissioning_date DATE, production_capacity TEXT, quality_unit_present BOOLEAN,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
