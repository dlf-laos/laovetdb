CREATE TABLE trade.quarantine_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), quarantine_no VARCHAR(120) NOT NULL UNIQUE,
 shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT, quarantine_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ NOT NULL, released_at TIMESTAMPTZ, release_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_quarantine_dates CHECK(released_at IS NULL OR released_at>=started_at));
CREATE TABLE trade.clearance_decision (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, clearance_type VARCHAR(50) NOT NULL, decided_at TIMESTAMPTZ NOT NULL, conditions TEXT);
CREATE INDEX idx_quarantine_shipment ON trade.quarantine_case(shipment_id,status); CREATE INDEX idx_clearance_shipment ON trade.clearance_decision(shipment_id,decided_at DESC);
