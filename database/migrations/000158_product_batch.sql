CREATE TABLE product.batch (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 product_version_id UUID REFERENCES product.product_version(id) ON DELETE RESTRICT, facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 batch_no VARCHAR(150) NOT NULL, manufacture_date DATE, expiry_date DATE, quantity NUMERIC(20,6), unit_code VARCHAR(30),
 release_status VARCHAR(30) NOT NULL DEFAULT 'PENDING', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(product_id,batch_no),
 CONSTRAINT ck_product_batch_dates CHECK(expiry_date IS NULL OR manufacture_date IS NULL OR expiry_date>=manufacture_date),
 CONSTRAINT ck_product_batch_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE INDEX idx_batch_product ON product.batch(product_id); CREATE INDEX idx_batch_number ON product.batch(batch_no);
