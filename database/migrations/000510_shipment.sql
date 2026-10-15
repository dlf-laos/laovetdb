CREATE TABLE trade.shipment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_no VARCHAR(120) NOT NULL UNIQUE,
 permit_id UUID REFERENCES trade.permit(id) ON DELETE RESTRICT, operator_id UUID NOT NULL REFERENCES trade.operator(id) ON DELETE RESTRICT,
 origin_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, destination_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 entry_exit_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, expected_arrival_at TIMESTAMPTZ, actual_arrival_at TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'DECLARED', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE trade.shipment_item (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 line_no INTEGER NOT NULL CHECK(line_no>0), commodity_class VARCHAR(50) NOT NULL, product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, description TEXT, quantity NUMERIC(20,6), unit_code VARCHAR(30),
 country_of_origin_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, UNIQUE(shipment_id,line_no), CONSTRAINT ck_shipment_item_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE TABLE trade.shipment_transport (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 mode_code VARCHAR(30), vehicle_or_vessel_reference VARCHAR(150), container_reference VARCHAR(150), carrier_name TEXT, seal_number VARCHAR(100));
CREATE INDEX idx_shipment_operator_status ON trade.shipment(operator_id,status,expected_arrival_at); CREATE INDEX idx_shipment_item_product ON trade.shipment_item(product_id) WHERE product_id IS NOT NULL;
