CREATE TABLE animal.ownership_history (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 owner_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, valid_from TIMESTAMPTZ NOT NULL, valid_to TIMESTAMPTZ, source_event_id UUID,
 CONSTRAINT ck_ownership_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE TABLE animal.location_history (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 valid_from TIMESTAMPTZ NOT NULL, valid_to TIMESTAMPTZ, source_type VARCHAR(50), source_id UUID,
 CONSTRAINT ck_location_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE INDEX idx_ownership_current ON animal.ownership_history(animal_id,valid_to); CREATE INDEX idx_location_current ON animal.location_history(animal_id,valid_to);
