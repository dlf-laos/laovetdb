CREATE TABLE trade.health_certificate (certificate_id UUID PRIMARY KEY REFERENCES document.certificate(id) ON DELETE RESTRICT,
 shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT, certificate_profile_code VARCHAR(100),
 destination_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, structured_payload JSONB NOT NULL);
CREATE INDEX idx_health_certificate_shipment ON trade.health_certificate(shipment_id);
