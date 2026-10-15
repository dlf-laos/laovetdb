CREATE TABLE lookup.breed (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT,
 code VARCHAR(100), name_lo TEXT, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE UNIQUE INDEX uq_breed_code ON lookup.breed(species_id,code) WHERE code IS NOT NULL;
CREATE INDEX idx_breed_species ON lookup.breed(species_id);
