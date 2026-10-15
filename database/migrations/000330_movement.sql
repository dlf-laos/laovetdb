CREATE TABLE animal.movement (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_no VARCHAR(120) NOT NULL UNIQUE,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, origin_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 destination_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, departure_at TIMESTAMPTZ, arrival_at TIMESTAMPTZ,
 purpose_code VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_movement_times CHECK(arrival_at IS NULL OR departure_at IS NULL OR arrival_at>=departure_at));
CREATE TABLE animal.movement_subject (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 quantity BIGINT CHECK(quantity IS NULL OR quantity>=0), CONSTRAINT ck_movement_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE TABLE animal.movement_transport (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 vehicle_reference VARCHAR(150), driver_name TEXT, driver_contact VARCHAR(100), cleaning_confirmed BOOLEAN, disinfection_confirmed BOOLEAN);
CREATE TABLE animal.movement_checkpoint (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, checked_at TIMESTAMPTZ, result_code VARCHAR(50),
 officer_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, notes TEXT);
CREATE INDEX idx_movement_origin ON animal.movement(origin_facility_id,departure_at); CREATE INDEX idx_movement_destination ON animal.movement(destination_facility_id,arrival_at);
CREATE INDEX idx_movement_subject_animal ON animal.movement_subject(animal_id) WHERE animal_id IS NOT NULL;
