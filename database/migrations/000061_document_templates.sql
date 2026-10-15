CREATE TABLE document.template (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, document_type VARCHAR(100) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE document.template_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_id UUID NOT NULL REFERENCES document.template(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), language_code VARCHAR(10) NOT NULL, effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 template_body TEXT, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(template_id,version_no,language_code),
 CONSTRAINT ck_template_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
