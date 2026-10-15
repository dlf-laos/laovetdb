CREATE TABLE farm.farm (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT, farm_code VARCHAR(120),
 production_system VARCHAR(100), commercial_scale VARCHAR(50), biosecurity_level VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_farm_code ON farm.farm(farm_code) WHERE farm_code IS NOT NULL;
CREATE TABLE farm.species_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, breed_id UUID REFERENCES lookup.breed(id) ON DELETE RESTRICT,
 production_type VARCHAR(100), valid_from DATE NOT NULL DEFAULT CURRENT_DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_farm_species_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE TABLE farm.population_snapshot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, snapshot_date DATE NOT NULL, total_count BIGINT NOT NULL CHECK(total_count>=0),
 male_count BIGINT CHECK(male_count IS NULL OR male_count>=0), female_count BIGINT CHECK(female_count IS NULL OR female_count>=0),
 young_count BIGINT CHECK(young_count IS NULL OR young_count>=0), source_type VARCHAR(50), created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE farm.biosecurity_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 assessment_date DATE NOT NULL, inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, score NUMERIC(10,4), classification VARCHAR(50), notes TEXT);
CREATE TABLE farm.production_cycle (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, cycle_no VARCHAR(120), start_date DATE, end_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_production_cycle_dates CHECK(end_date IS NULL OR start_date IS NULL OR end_date>=start_date));
CREATE INDEX idx_farm_species_farm ON farm.species_assignment(farm_id,status); CREATE INDEX idx_farm_population_date ON farm.population_snapshot(farm_id,species_id,snapshot_date DESC);
