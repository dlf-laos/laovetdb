CREATE TABLE product.manufacturer_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 manufacturer_party_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT, manufacturing_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 responsibility_type VARCHAR(50) NOT NULL DEFAULT 'MANUFACTURER', valid_from DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_manufacturer_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_product_manufacturer_company ON product.manufacturer_assignment(manufacturer_party_id); CREATE INDEX idx_product_manufacturer_product ON product.manufacturer_assignment(product_id,status);
