-- Additive ledger. Registration and legal eligibility remain separate from AMU surveillance.
CREATE TABLE analytics.amu_movement (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 source_key TEXT NOT NULL UNIQUE,
 movement_date DATE NOT NULL,
 movement_type TEXT NOT NULL CHECK(movement_type IN ('IMPORT','EXPORT','RE_EXPORT','TRANSIT')),
 product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
 application_item_id UUID REFERENCES trade.import_application_item(id) ON DELETE RESTRICT,
 payload JSONB NOT NULL,
 calculation JSONB NOT NULL,
 status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','REVIEWED','VOID')),
 version INTEGER NOT NULL DEFAULT 1 CHECK(version>0),
 created_by UUID NOT NULL REFERENCES security.app_user(id),
 reviewed_by UUID REFERENCES security.app_user(id),
 review_note TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
