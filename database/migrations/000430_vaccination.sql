CREATE TABLE disease.vaccination_campaign (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), campaign_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, name_lo TEXT NOT NULL, name_en TEXT, start_date DATE, end_date DATE,
 target_definition JSONB, status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', CONSTRAINT ck_campaign_dates CHECK(end_date IS NULL OR start_date IS NULL OR end_date>=start_date));
CREATE TABLE disease.vaccination_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), campaign_id UUID REFERENCES disease.vaccination_campaign(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 farm_id UUID REFERENCES farm.farm(facility_id) ON DELETE RESTRICT, vaccine_product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 product_batch_id UUID REFERENCES product.batch(id) ON DELETE RESTRICT, vaccinated_at TIMESTAMPTZ NOT NULL,
 vaccinated_quantity BIGINT CHECK(vaccinated_quantity IS NULL OR vaccinated_quantity>=0), administered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_vaccination_subject CHECK(animal_id IS NOT NULL OR animal_group_id IS NOT NULL OR farm_id IS NOT NULL));
CREATE INDEX idx_vaccination_animal ON disease.vaccination_event(animal_id,vaccinated_at DESC) WHERE animal_id IS NOT NULL;
CREATE INDEX idx_vaccination_farm ON disease.vaccination_event(farm_id,vaccinated_at DESC) WHERE farm_id IS NOT NULL;
