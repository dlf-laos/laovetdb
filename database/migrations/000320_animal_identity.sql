CREATE TABLE animal.animal (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_no VARCHAR(120), species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT,
 breed_id UUID REFERENCES lookup.breed(id) ON DELETE RESTRICT, sex_code VARCHAR(20), birth_date DATE, birth_date_estimated BOOLEAN NOT NULL DEFAULT FALSE,
 lifecycle_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_animal_no ON animal.animal(animal_no) WHERE animal_no IS NOT NULL;
CREATE TABLE animal.identifier (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 identifier_type VARCHAR(40) NOT NULL, identifier_value VARCHAR(150) NOT NULL, issued_at TIMESTAMPTZ, retired_at TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(identifier_type,identifier_value));
CREATE TABLE animal.animal_group (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), group_no VARCHAR(120) NOT NULL UNIQUE,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, farm_id UUID REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 production_batch_reference VARCHAR(150), initial_quantity BIGINT CHECK(initial_quantity IS NULL OR initial_quantity>=0),
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_animal_species ON animal.animal(species_id,lifecycle_status); CREATE INDEX idx_animal_group_farm ON animal.animal_group(farm_id,status);
