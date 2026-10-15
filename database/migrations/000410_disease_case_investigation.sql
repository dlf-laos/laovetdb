CREATE TABLE disease.disease_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, surveillance_event_id UUID REFERENCES disease.surveillance_event(id) ON DELETE RESTRICT,
 premises_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 case_classification VARCHAR(40) NOT NULL DEFAULT 'SUSPECTED', onset_date DATE, reported_at TIMESTAMPTZ NOT NULL DEFAULT now(), confirmed_at TIMESTAMPTZ,
 closed_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'OPEN');
CREATE TABLE disease.disease_case_subject (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 affected_quantity BIGINT CHECK(affected_quantity IS NULL OR affected_quantity>=0), morbidity_quantity BIGINT CHECK(morbidity_quantity IS NULL OR morbidity_quantity>=0),
 mortality_quantity BIGINT CHECK(mortality_quantity IS NULL OR mortality_quantity>=0),
 CONSTRAINT ck_disease_case_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE TABLE disease.investigation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 investigation_no INTEGER NOT NULL CHECK(investigation_no>0), investigator_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, clinical_summary TEXT, epidemiological_summary TEXT, suspected_source TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'OPEN', UNIQUE(disease_case_id,investigation_no));
CREATE TABLE disease.epidemiological_link (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 target_case_id UUID REFERENCES disease.disease_case(id) ON DELETE RESTRICT, movement_id UUID REFERENCES animal.movement(id) ON DELETE RESTRICT,
 link_type VARCHAR(50) NOT NULL, confidence_level VARCHAR(30), description TEXT, identified_at TIMESTAMPTZ NOT NULL DEFAULT now());
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_disease_case FOREIGN KEY(disease_case_id) REFERENCES disease.disease_case(id) ON DELETE RESTRICT;
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_animal FOREIGN KEY(animal_id) REFERENCES animal.animal(id) ON DELETE RESTRICT;
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_animal_group FOREIGN KEY(animal_group_id) REFERENCES animal.animal_group(id) ON DELETE RESTRICT;
CREATE INDEX idx_disease_case_disease_status ON disease.disease_case(disease_id,status,reported_at DESC);
