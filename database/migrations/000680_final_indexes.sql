CREATE INDEX IF NOT EXISTS idx_party_role_active ON master.party_role_assignment(party_id,role_type_id,valid_to) WHERE status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_facility_type_active ON master.facility_type_assignment(facility_id,facility_type_id,valid_to) WHERE status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_case_workflow ON casework.regulatory_case(workflow_instance_id) WHERE workflow_instance_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_certificate_verify ON document.certificate(verification_token) WHERE verification_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inspection_visit_location ON inspection.visit USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_inspection_evidence_location ON inspection.evidence USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_sample_source_facility ON laboratory.sample(source_facility_id,collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_movement_status_departure ON animal.movement(status,departure_at);
CREATE INDEX IF NOT EXISTS idx_disease_case_admin ON disease.disease_case(admin_unit_id,reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_outbreak_disease_status ON disease.outbreak(disease_id,status,confirmation_date DESC);
CREATE INDEX IF NOT EXISTS idx_trade_shipment_arrival ON trade.shipment(entry_exit_facility_id,expected_arrival_at,status);
CREATE INDEX IF NOT EXISTS idx_trade_item_class ON trade.shipment_item(commodity_class);
CREATE INDEX IF NOT EXISTS idx_aquaculture_stock_species ON fisheries.stock_batch(species_id,status);

-- Database guardrails for official/audit history. Business correction uses linked new records, not hard delete.
CREATE TRIGGER trg_no_delete_regulatory_decision BEFORE DELETE ON casework.regulatory_decision
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_registration BEFORE DELETE ON registration.registration
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_license BEFORE DELETE ON licensing.license
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_certificate BEFORE DELETE ON document.certificate
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_audit_event BEFORE DELETE ON audit.event
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_inspection_evidence BEFORE DELETE ON inspection.evidence
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_lab_result_version BEFORE DELETE ON laboratory.result_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_approved_lab_result_immutable BEFORE UPDATE ON laboratory.result_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('APPROVED');
CREATE TRIGGER trg_no_delete_animal_lifecycle BEFORE DELETE ON animal.lifecycle_event
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_outbreak BEFORE DELETE ON disease.outbreak
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_trade_permit BEFORE DELETE ON trade.permit
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_trade_shipment BEFORE DELETE ON trade.shipment
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
