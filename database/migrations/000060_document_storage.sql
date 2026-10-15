CREATE TABLE document.document (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), document_type VARCHAR(100) NOT NULL, title TEXT,
 classification VARCHAR(30) NOT NULL DEFAULT 'INTERNAL', business_entity_type VARCHAR(100), business_entity_id UUID,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE TABLE document.file (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), document_id UUID NOT NULL REFERENCES document.document(id) ON DELETE RESTRICT,
 storage_provider VARCHAR(50) NOT NULL, object_key TEXT NOT NULL, original_filename TEXT, mime_type VARCHAR(255), size_bytes BIGINT CHECK(size_bytes IS NULL OR size_bytes>=0),
 sha256_checksum VARCHAR(64), uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), uploaded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 UNIQUE(storage_provider,object_key));
CREATE INDEX idx_document_business_entity ON document.document(business_entity_type,business_entity_id);
