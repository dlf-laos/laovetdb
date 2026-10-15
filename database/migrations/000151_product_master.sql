CREATE TABLE product.product (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_code VARCHAR(100), product_type_id UUID NOT NULL REFERENCES product.product_type(id) ON DELETE RESTRICT,
 trade_name TEXT NOT NULL, generic_name TEXT, lifecycle_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE UNIQUE INDEX uq_product_code ON product.product(product_code) WHERE product_code IS NOT NULL;
CREATE INDEX idx_product_trade_name_trgm ON product.product USING GIN(trade_name gin_trgm_ops); CREATE INDEX idx_product_type ON product.product(product_type_id);
CREATE TRIGGER trg_product_updated_at BEFORE UPDATE ON product.product FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
ALTER TABLE registration.product_registration ADD CONSTRAINT fk_product_registration_product FOREIGN KEY(product_id) REFERENCES product.product(id) ON DELETE RESTRICT;
