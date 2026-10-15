CREATE TABLE trade.risk_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 risk_model_version VARCHAR(100) NOT NULL, assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(), risk_score NUMERIC(10,4), risk_band VARCHAR(30),
 required_control VARCHAR(50), explanation JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE INDEX idx_trade_risk_shipment ON trade.risk_assessment(shipment_id,assessed_at DESC);
