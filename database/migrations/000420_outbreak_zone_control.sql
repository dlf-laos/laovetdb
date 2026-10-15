CREATE TABLE disease.outbreak (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID NOT NULL REFERENCES disease.disease(id) ON DELETE RESTRICT, confirmation_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 outbreak_start_date DATE, confirmation_date DATE, closure_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE disease.outbreak_case (outbreak_id UUID NOT NULL REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT, PRIMARY KEY(outbreak_id,disease_case_id));
CREATE TABLE disease.zone (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_id UUID NOT NULL REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 zone_type VARCHAR(50) NOT NULL, zone_name TEXT, geometry geometry(MultiPolygon,4326), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_zone_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE disease.control_measure (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 disease_case_id UUID REFERENCES disease.disease_case(id) ON DELETE RESTRICT, zone_id UUID REFERENCES disease.zone(id) ON DELETE RESTRICT, measure_type VARCHAR(50) NOT NULL,
 started_at TIMESTAMPTZ, ended_at TIMESTAMPTZ, authority_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE disease.movement_restriction (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT,
 outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT, zone_id UUID REFERENCES disease.zone(id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, restriction_type VARCHAR(50) NOT NULL, effective_from TIMESTAMPTZ NOT NULL,
 effective_to TIMESTAMPTZ, decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_restriction_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_zone_geometry ON disease.zone USING GIST(geometry); CREATE INDEX idx_active_restriction ON disease.movement_restriction(species_id,effective_from,effective_to) WHERE status='ACTIVE';
