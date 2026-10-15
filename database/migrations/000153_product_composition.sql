CREATE TABLE product.product_ingredient (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id UUID NOT NULL REFERENCES product.product_version(id) ON DELETE RESTRICT,
 ingredient_id UUID NOT NULL REFERENCES product.ingredient(id) ON DELETE RESTRICT, ingredient_role VARCHAR(50), amount NUMERIC(18,6), unit_code VARCHAR(30), amount_basis TEXT,
 CONSTRAINT ck_product_ingredient_amount CHECK(amount IS NULL OR amount>=0));
CREATE INDEX idx_product_ingredient_version ON product.product_ingredient(product_version_id); CREATE INDEX idx_product_ingredient_ingredient ON product.product_ingredient(ingredient_id);
