CREATE TABLE laboratory.laboratory (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 laboratory_code VARCHAR(100) UNIQUE, laboratory_level VARCHAR(50), accreditation_status VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
