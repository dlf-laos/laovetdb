CREATE TABLE laboratory.sample (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_no VARCHAR(120) NOT NULL UNIQUE, sample_type VARCHAR(100) NOT NULL,
 source_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 disease_case_id UUID, animal_id UUID, animal_group_id UUID, collected_at TIMESTAMPTZ, collected_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 received_laboratory_id UUID REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT, received_at TIMESTAMPTZ,
 sample_status VARCHAR(30) NOT NULL DEFAULT 'COLLECTED', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE laboratory.sample_custody_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT,
 event_type VARCHAR(50) NOT NULL, from_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, to_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 occurred_at TIMESTAMPTZ NOT NULL, temperature NUMERIC(8,3), condition_code VARCHAR(50), location geography(Point,4326),
 recorded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, notes TEXT);
CREATE INDEX idx_sample_lab_status ON laboratory.sample(received_laboratory_id,sample_status); CREATE INDEX idx_sample_inspection ON laboratory.sample(inspection_case_id);
CREATE INDEX idx_sample_custody_time ON laboratory.sample_custody_event(sample_id,occurred_at);
