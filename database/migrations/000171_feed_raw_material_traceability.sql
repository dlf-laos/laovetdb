CREATE TABLE feed.raw_material_lot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 material_name TEXT NOT NULL, supplier_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, supplier_lot_no VARCHAR(150), received_date DATE,
 quantity NUMERIC(20,6), unit_code VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE', CONSTRAINT ck_raw_material_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE TABLE feed.batch_material_usage (batch_id UUID NOT NULL REFERENCES product.batch(id) ON DELETE RESTRICT,
 raw_material_lot_id UUID NOT NULL REFERENCES feed.raw_material_lot(id) ON DELETE RESTRICT, quantity_used NUMERIC(20,6), unit_code VARCHAR(30),
 PRIMARY KEY(batch_id,raw_material_lot_id), CONSTRAINT ck_batch_material_qty CHECK(quantity_used IS NULL OR quantity_used>=0));
CREATE INDEX idx_raw_material_facility ON feed.raw_material_lot(facility_id,status);
