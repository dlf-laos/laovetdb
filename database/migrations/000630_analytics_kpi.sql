CREATE TABLE analytics.kpi_definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), kpi_code VARCHAR(100) NOT NULL UNIQUE, domain_code VARCHAR(50) NOT NULL,
 name_lo TEXT NOT NULL, name_en TEXT, calculation_version INTEGER NOT NULL DEFAULT 1 CHECK(calculation_version>0), unit_code VARCHAR(30), definition TEXT,
 configuration JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE analytics.metric_snapshot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), kpi_id UUID NOT NULL REFERENCES analytics.kpi_definition(id) ON DELETE RESTRICT,
 period_start TIMESTAMPTZ NOT NULL, period_end TIMESTAMPTZ NOT NULL, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT, numeric_value NUMERIC(30,8), calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_metric_period CHECK(period_end>=period_start));
CREATE TABLE analytics.dashboard_definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dashboard_code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, audience_code VARCHAR(50), configuration JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE INDEX idx_metric_kpi_period ON analytics.metric_snapshot(kpi_id,period_start,period_end);
