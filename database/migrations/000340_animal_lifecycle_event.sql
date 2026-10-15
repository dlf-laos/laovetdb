CREATE TABLE animal.lifecycle_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT,
 animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT, event_type VARCHAR(50) NOT NULL, occurred_at TIMESTAMPTZ NOT NULL,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, related_entity_type VARCHAR(100), related_entity_id UUID, details JSONB,
 recorded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_lifecycle_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE INDEX idx_lifecycle_animal_time ON animal.lifecycle_event(animal_id,occurred_at DESC) WHERE animal_id IS NOT NULL;
CREATE INDEX idx_lifecycle_group_time ON animal.lifecycle_event(animal_group_id,occurred_at DESC) WHERE animal_group_id IS NOT NULL;
