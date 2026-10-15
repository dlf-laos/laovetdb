CREATE TABLE trade.border_declaration (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 declaration_no VARCHAR(120), declaration_type VARCHAR(30) NOT NULL DEFAULT 'PRE_ARRIVAL', submitted_at TIMESTAMPTZ,
 external_customs_reference VARCHAR(200), status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED');
CREATE UNIQUE INDEX uq_border_declaration_no ON trade.border_declaration(declaration_no) WHERE declaration_no IS NOT NULL;
CREATE INDEX idx_border_declaration_shipment ON trade.border_declaration(shipment_id,submitted_at DESC);
