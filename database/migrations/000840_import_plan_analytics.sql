-- LVSP v1.9.0 — Import Plan & Analytics
-- Non-destructive analytics layer over 000780 + 000790 + 000810.
-- Purpose:
--   * Track annual plan vs approved vs actual cleared imports.
--   * Never subtract incompatible quantity units.
--   * Support category/summary plans by item-count/value rather than mixing units.
--   * Power company/product/checkpoint rankings and drill-down reports.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('trade.import_plan') IS NULL THEN missing := array_append(missing,'trade.import_plan'); END IF;
  IF to_regclass('trade.import_plan_item') IS NULL THEN missing := array_append(missing,'trade.import_plan_item'); END IF;
  IF to_regclass('trade.import_plan_item_profile') IS NULL THEN missing := array_append(missing,'trade.import_plan_item_profile'); END IF;
  IF to_regclass('trade.import_application') IS NULL THEN missing := array_append(missing,'trade.import_application'); END IF;
  IF to_regclass('trade.import_application_item') IS NULL THEN missing := array_append(missing,'trade.import_application_item'); END IF;
  IF to_regclass('master.company') IS NULL THEN missing := array_append(missing,'master.company'); END IF;
  IF cardinality(missing)>0 THEN
    RAISE EXCEPTION '000840 prerequisites missing: %',array_to_string(missing,', ');
  END IF;
END $$;

-- One row per application item.  This is the stable source for analytics.
CREATE OR REPLACE VIEW analytics.v_import_transaction_detail AS
SELECT
  iai.id AS application_item_id,
  ia.id AS application_id,
  ia.application_no,
  ia.permit_no,
  ia.import_type AS movement_type,
  ia.application_date,
  ia.decision_date,
  ia.cleared_date,
  ia.status AS application_status,
  ia.company_id,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
  ia.plan_id,
  ip.plan_no,
  ip.plan_year,
  iai.plan_item_id,
  pi.item_no AS plan_item_no,
  pi.item_name AS plan_reference_name,
  pi.item_type AS plan_item_type,
  pi.line_mode,
  pi.group_code,
  pi.group_name,
  COALESCE(pip.scope_type,'ITEM') AS scope_type,
  COALESCE(pip.category_code,pi.group_code) AS category_code,
  CASE
    WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
         AND (
           COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
           OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
         )
      THEN 'COUNT_VALUE'
    ELSE COALESCE(pip.tracking_basis,'QUANTITY')
  END AS tracking_basis,
  COALESCE(
    pip.planned_item_count,
    pi.planned_item_count,
    CASE WHEN COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
              OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
         THEN CASE WHEN pi.planned_quantity BETWEEN 0 AND 2147483647 THEN floor(pi.planned_quantity)::integer END
    END
  ) AS planned_item_count,
  pi.planned_quantity,
  COALESCE(pip.planned_value_usd,pi.planned_value) AS planned_value_usd,
  pi.unit_code AS plan_unit_code,
  iai.item_no AS application_item_no,
  iai.item_type,
  iai.item_name,
  iai.product_id,
  iai.device_id,
  iai.registration_no,
  iai.package_description,
  iai.requested_quantity,
  iai.approved_quantity,
  COALESCE(iai.cleared_quantity,iai.cleared_packs,0)::numeric(18,3) AS cleared_quantity,
  iai.unit_code,
  iai.item_value,
  iai.currency_code,
  iai.eligibility_status,
  iai.antimicrobial,
  iai.active_substance_kg,
  ia.origin_country,
  ia.destination_country,
  ia.border_checkpoint,
  ia.checkpoint_out,
  ia.transport_mode,
  COALESCE(pr.manufacturer_name,'') AS manufacturer_name,
  COALESCE(pr.manufacturer_country,'') AS manufacturer_country,
  CASE
    WHEN iai.plan_item_id IS NULL THEN NULL
    WHEN NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL THEN TRUE
    WHEN NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL THEN TRUE
    ELSE lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code))
  END AS unit_compatible,
  CASE
    WHEN iai.plan_item_id IS NOT NULL
         AND (NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL
              OR NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL
              OR lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code)))
         AND (CASE
              WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
                   AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                        OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
                THEN 'COUNT_VALUE'
              ELSE COALESCE(pip.tracking_basis,'QUANTITY') END) IN ('QUANTITY','QUANTITY_VALUE')
      THEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0)::numeric(18,3)
    ELSE 0::numeric(18,3)
  END AS safe_cleared_quantity,
  CASE
    WHEN iai.plan_item_id IS NOT NULL
         AND (NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL
              OR NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL
              OR lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code)))
         AND (CASE
              WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
                   AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                        OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
                THEN 'COUNT_VALUE'
              ELSE COALESCE(pip.tracking_basis,'QUANTITY') END) IN ('QUANTITY','QUANTITY_VALUE')
      THEN COALESCE(iai.approved_quantity,iai.requested_quantity,0)::numeric(18,3)
    ELSE 0::numeric(18,3)
  END AS safe_approved_quantity,
  CASE
    WHEN upper(COALESCE(ia.status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED')
      THEN COALESCE(iai.item_value,0)::numeric(20,2)
    ELSE 0::numeric(20,2)
  END AS approved_value_usd,
  CASE
    WHEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0)>0
         AND COALESCE(iai.item_value,0)>0
         AND COALESCE(iai.approved_quantity,iai.requested_quantity,0)>0
      THEN ROUND(
        COALESCE(iai.item_value,0)
        * LEAST(1::numeric,
          COALESCE(iai.cleared_quantity,iai.cleared_packs,0)
          / NULLIF(COALESCE(iai.approved_quantity,iai.requested_quantity,0),0)
        ),2)
    WHEN upper(COALESCE(ia.status,'')) IN ('CLEARED','CLOSED','COMPLETED')
      THEN COALESCE(iai.item_value,0)::numeric(20,2)
    ELSE 0::numeric(20,2)
  END AS actual_cleared_value_usd,
  CASE
    WHEN iai.product_id IS NOT NULL THEN 'PRODUCT:'||iai.product_id::text
    WHEN iai.device_id IS NOT NULL THEN 'DEVICE:'||iai.device_id::text
    WHEN NULLIF(btrim(COALESCE(iai.registration_no,'')),'') IS NOT NULL THEN 'REG:'||lower(btrim(iai.registration_no))
    ELSE 'NAME:'||lower(regexp_replace(btrim(COALESCE(iai.item_name,'')),'\s+',' ','g'))
  END AS actual_item_key,
  ia.created_at AS application_created_at,
  ia.updated_at AS application_updated_at,
  iai.created_at AS item_created_at
FROM trade.import_application_item iai
JOIN trade.import_application ia ON ia.id=iai.application_id
LEFT JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_plan ip ON ip.id=ia.plan_id
LEFT JOIN trade.import_plan_item pi ON pi.id=iai.plan_item_id
LEFT JOIN trade.import_plan_item_profile pip ON pip.plan_item_id=pi.id
LEFT JOIN product.product_regulatory_profile pr ON pr.product_id=iai.product_id;

COMMENT ON VIEW analytics.v_import_transaction_detail IS
'One row per trade application item for plan/import analytics. Quantities are kept by unit; safe_* quantity fields are zero when plan/application units are incompatible or the plan tracks count/value instead of quantity.';

-- One row per annual-plan line with tracking-basis-aware balances.
CREATE OR REPLACE VIEW analytics.v_import_plan_tracking AS
WITH base AS (
  SELECT
    pi.id AS plan_item_id,
    pi.plan_id,
    ip.plan_no,
    ip.plan_year,
    ip.company_id,
    COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
    pi.item_no,
    pi.item_type,
    pi.item_name,
    pi.registration_no,
    pi.line_mode,
    pi.group_code,
    pi.group_name,
    pi.unit_code,
    pi.planned_quantity,
    COALESCE(pip.planned_value_usd,pi.planned_value) AS planned_value_usd,
    COALESCE(pip.scope_type,'ITEM') AS scope_type,
    COALESCE(pip.category_code,pi.group_code) AS category_code,
    CASE
      WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
           AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
        THEN 'COUNT_VALUE'
      ELSE COALESCE(pip.tracking_basis,'QUANTITY')
    END AS tracking_basis,
    COALESCE(
      pip.planned_item_count,
      pi.planned_item_count,
      CASE WHEN COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
           THEN CASE WHEN pi.planned_quantity BETWEEN 0 AND 2147483647 THEN floor(pi.planned_quantity)::integer END
      END
    ) AS planned_item_count
  FROM trade.import_plan_item pi
  JOIN trade.import_plan ip ON ip.id=pi.plan_id
  LEFT JOIN master.company c ON c.party_id=ip.company_id
  LEFT JOIN trade.import_plan_item_profile pip ON pip.plan_item_id=pi.id
  WHERE COALESCE(pi.record_status,'ACTIVE')='ACTIVE'
), actual AS (
  SELECT
    d.plan_item_id,
    COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
    COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.actual_item_key END)::integer AS approved_item_count,
    COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
    COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.actual_item_key END)::integer AS actual_item_count,
    COALESCE(SUM(d.safe_approved_quantity),0)::numeric(20,3) AS approved_quantity,
    COALESCE(SUM(d.safe_cleared_quantity),0)::numeric(20,3) AS actual_cleared_quantity,
    COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
    COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd,
    COUNT(*) FILTER (WHERE d.plan_item_id IS NOT NULL AND d.unit_compatible=FALSE)::integer AS unit_mismatch_count,
    COUNT(*)::integer AS linked_line_count
  FROM analytics.v_import_transaction_detail d
  WHERE d.plan_item_id IS NOT NULL
  GROUP BY d.plan_item_id
)
SELECT
  b.*,
  COALESCE(a.approval_count,0) AS approval_count,
  COALESCE(a.approved_item_count,0) AS approved_item_count,
  COALESCE(a.import_count,0) AS import_count,
  COALESCE(a.actual_item_count,0) AS actual_item_count,
  COALESCE(a.approved_quantity,0) AS approved_quantity,
  COALESCE(a.actual_cleared_quantity,0) AS actual_cleared_quantity,
  COALESCE(a.approved_value_usd,0) AS approved_value_usd,
  COALESCE(a.actual_cleared_value_usd,0) AS actual_cleared_value_usd,
  COALESCE(a.unit_mismatch_count,0) AS unit_mismatch_count,
  COALESCE(a.linked_line_count,0) AS linked_line_count,
  CASE WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE')
       THEN b.planned_quantity-COALESCE(a.actual_cleared_quantity,0) END AS remaining_quantity,
  CASE WHEN b.tracking_basis IN ('COUNT_VALUE')
       THEN b.planned_item_count-COALESCE(a.actual_item_count,0) END AS remaining_item_count,
  CASE WHEN b.tracking_basis IN ('VALUE','QUANTITY_VALUE','COUNT_VALUE') AND b.planned_value_usd IS NOT NULL
       THEN b.planned_value_usd-COALESCE(a.actual_cleared_value_usd,0) END AS remaining_value_usd,
  CASE
    WHEN COALESCE(a.unit_mismatch_count,0)>0 AND b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') THEN 'UNIT_MISMATCH'
    WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') AND COALESCE(a.actual_cleared_quantity,0)>b.planned_quantity THEN 'OVER_PLAN'
    WHEN b.tracking_basis='COUNT_VALUE' AND b.planned_item_count IS NOT NULL AND COALESCE(a.actual_item_count,0)>b.planned_item_count THEN 'OVER_PLAN'
    WHEN b.tracking_basis IN ('VALUE','QUANTITY_VALUE','COUNT_VALUE') AND b.planned_value_usd IS NOT NULL AND COALESCE(a.actual_cleared_value_usd,0)>b.planned_value_usd THEN 'OVER_PLAN'
    WHEN b.tracking_basis='REFERENCE_ONLY' THEN 'REFERENCE_ONLY'
    WHEN COALESCE(a.import_count,0)=0 THEN 'NOT_USED'
    WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') AND b.planned_quantity-COALESCE(a.actual_cleared_quantity,0)<=0 THEN 'EXHAUSTED'
    WHEN b.tracking_basis='COUNT_VALUE' AND b.planned_item_count IS NOT NULL AND b.planned_item_count-COALESCE(a.actual_item_count,0)<=0 THEN 'EXHAUSTED'
    WHEN b.tracking_basis='VALUE' AND b.planned_value_usd IS NOT NULL AND b.planned_value_usd-COALESCE(a.actual_cleared_value_usd,0)<=0 THEN 'EXHAUSTED'
    ELSE 'AVAILABLE'
  END AS tracking_status
FROM base b
LEFT JOIN actual a ON a.plan_item_id=b.plan_item_id;

COMMENT ON VIEW analytics.v_import_plan_tracking IS
'Annual-plan line tracking with separate quantity, value and item-count bases. Summary/category plans track distinct item counts (with optional value) and never subtract mixed physical units from item counts.';

CREATE OR REPLACE VIEW analytics.v_import_company_summary AS
SELECT
  d.company_id,
  d.company_name,
  COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer) AS report_year,
  COUNT(DISTINCT d.application_id)::integer AS application_count,
  COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
  COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
  COUNT(DISTINCT d.actual_item_key)::integer AS unique_item_count,
  COUNT(*)::integer AS line_count,
  COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
  COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd,
  COALESCE(SUM(d.active_substance_kg),0)::numeric(20,6) AS active_substance_kg
FROM analytics.v_import_transaction_detail d
GROUP BY d.company_id,d.company_name,COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer);

CREATE OR REPLACE VIEW analytics.v_import_product_summary AS
SELECT
  d.actual_item_key,
  d.item_name,
  d.registration_no,
  d.item_type,
  d.unit_code,
  COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer) AS report_year,
  COUNT(DISTINCT d.application_id)::integer AS application_count,
  COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
  COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
  COUNT(DISTINCT d.company_id)::integer AS company_count,
  COALESCE(SUM(d.requested_quantity),0)::numeric(20,3) AS requested_quantity,
  COALESCE(SUM(COALESCE(d.approved_quantity,d.requested_quantity,0)),0)::numeric(20,3) AS approved_quantity,
  COALESCE(SUM(d.cleared_quantity),0)::numeric(20,3) AS actual_cleared_quantity,
  COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
  COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd
FROM analytics.v_import_transaction_detail d
GROUP BY d.actual_item_key,d.item_name,d.registration_no,d.item_type,d.unit_code,
         COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer);

COMMENT ON VIEW analytics.v_import_product_summary IS
'Product summary groups quantity by product and unit. Different units are deliberately never merged into one quantity total.';
