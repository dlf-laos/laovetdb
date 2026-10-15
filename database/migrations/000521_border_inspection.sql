CREATE TABLE trade.border_inspection (shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, PRIMARY KEY(shipment_id,inspection_case_id));
