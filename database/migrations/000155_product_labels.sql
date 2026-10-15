CREATE TABLE product.label_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), package_version_id UUID NOT NULL REFERENCES product.package_version(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), language_code VARCHAR(10), document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(package_version_id,version_no,language_code),
 CONSTRAINT ck_label_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
