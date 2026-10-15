-- LVSP v0.6.0 — legacy trade migration, print support, AMR/ANIMUSE reference
ALTER TABLE trade.import_application
  ADD COLUMN IF NOT EXISTS legacy_source_id TEXT,
  ADD COLUMN IF NOT EXISTS legacy_source TEXT,
  ADD COLUMN IF NOT EXISTS signed_by TEXT,
  ADD COLUMN IF NOT EXISTS purpose TEXT,
  ADD COLUMN IF NOT EXISTS valid_from DATE,
  ADD COLUMN IF NOT EXISTS cleared_date DATE,
  ADD COLUMN IF NOT EXISTS destination_country TEXT,
  ADD COLUMN IF NOT EXISTS checkpoint_out TEXT,
  ADD COLUMN IF NOT EXISTS transport_mode TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_application_legacy_source_id ON trade.import_application(legacy_source_id) WHERE legacy_source_id IS NOT NULL;

ALTER TABLE trade.import_application_item
  ADD COLUMN IF NOT EXISTS legacy_source_id TEXT,
  ADD COLUMN IF NOT EXISTS legacy_kind TEXT,
  ADD COLUMN IF NOT EXISTS sub_code TEXT,
  ADD COLUMN IF NOT EXISTS gross_weight_kg NUMERIC(18,6),
  ADD COLUMN IF NOT EXISTS cleared_packs NUMERIC(18,3),
  ADD COLUMN IF NOT EXISTS amr_use TEXT,
  ADD COLUMN IF NOT EXISTS amr_group TEXT,
  ADD COLUMN IF NOT EXISTS amr_route TEXT,
  ADD COLUMN IF NOT EXISTS kg_override JSONB;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_application_item_legacy_source_id ON trade.import_application_item(legacy_source_id) WHERE legacy_source_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS analytics.amr_substance_reference (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  substance_key TEXT NOT NULL UNIQUE,
  substance_name_en TEXT NOT NULL,
  animuse_class_code TEXT,
  iu_per_mg NUMERIC,
  ionophore BOOLEAN NOT NULL DEFAULT FALSE,
  source TEXT,
  legacy_source_id TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_amr_substance_class ON analytics.amr_substance_reference(animuse_class_code);

CREATE OR REPLACE VIEW analytics.v_import_item_summary AS
SELECT
  ia.id AS application_id,
  ia.application_no,
  ia.application_date,
  ia.permit_no,
  ia.status,
  c.legal_name_lo AS company_name_lo,
  c.legal_name_en AS company_name_en,
  iai.item_type,
  COUNT(*) AS item_count,
  COALESCE(SUM(iai.requested_quantity),0) AS requested_quantity,
  COALESCE(SUM(iai.cleared_quantity),0) AS cleared_quantity,
  COALESCE(SUM(iai.item_value),0) AS value_usd,
  COALESCE(SUM(iai.gross_weight_kg),0) AS gross_weight_kg
FROM trade.import_application ia
JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_application_item iai ON iai.application_id=ia.id
GROUP BY ia.id, ia.application_no, ia.application_date, ia.permit_no, ia.status, c.legal_name_lo, c.legal_name_en, iai.item_type;
