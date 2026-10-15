CREATE TABLE product.package (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 package_code VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_package_code ON product.package(product_id,package_code) WHERE package_code IS NOT NULL;
CREATE TABLE product.package_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), package_id UUID NOT NULL REFERENCES product.package(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), pack_size NUMERIC(18,6), unit_code VARCHAR(30), container_type VARCHAR(100), pack_description TEXT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(package_id,version_no),
 CONSTRAINT ck_package_size CHECK(pack_size IS NULL OR pack_size>0), CONSTRAINT ck_package_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE INDEX idx_package_product ON product.package(product_id);
