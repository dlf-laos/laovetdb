CREATE TABLE laboratory.equipment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), laboratory_id UUID NOT NULL REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT,
 equipment_code VARCHAR(100), name TEXT NOT NULL, serial_no VARCHAR(150), calibration_due_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_lab_equipment_code ON laboratory.equipment(laboratory_id,equipment_code) WHERE equipment_code IS NOT NULL;
CREATE TABLE laboratory.calibration (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), equipment_id UUID NOT NULL REFERENCES laboratory.equipment(id) ON DELETE RESTRICT,
 calibration_date DATE NOT NULL, next_due_date DATE, result VARCHAR(30), certificate_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 CONSTRAINT ck_calibration_dates CHECK(next_due_date IS NULL OR next_due_date>=calibration_date));
CREATE TABLE laboratory.quality_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), laboratory_id UUID NOT NULL REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT,
 event_type VARCHAR(50) NOT NULL, event_date DATE NOT NULL, description TEXT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN');
CREATE INDEX idx_equipment_calibration_due ON laboratory.equipment(calibration_due_date) WHERE status='ACTIVE';
