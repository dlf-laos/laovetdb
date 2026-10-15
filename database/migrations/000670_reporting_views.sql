CREATE OR REPLACE VIEW analytics.v_active_licenses AS
SELECT id,license_no,license_type_id,holder_party_id,issue_date,effective_from,expiry_date,status FROM licensing.license WHERE status IN ('ACTIVE','VALID','ISSUED');
CREATE OR REPLACE VIEW analytics.v_active_registrations AS
SELECT id,registration_no,registration_type_id,holder_party_id,issue_date,effective_from,expiry_date,status FROM registration.registration WHERE status IN ('ACTIVE','VALID','ISSUED');
CREATE OR REPLACE VIEW analytics.v_open_inspection_findings AS
SELECT f.id,f.inspection_case_id,f.finding_no,f.severity_code,f.status,f.due_date,c.facility_id FROM inspection.finding f JOIN inspection.inspection_case c ON c.id=f.inspection_case_id WHERE f.status NOT IN ('CLOSED','RESOLVED');
CREATE OR REPLACE VIEW analytics.v_current_outbreaks AS
SELECT id,outbreak_no,disease_id,outbreak_start_date,confirmation_date,status FROM disease.outbreak WHERE status='ACTIVE';
