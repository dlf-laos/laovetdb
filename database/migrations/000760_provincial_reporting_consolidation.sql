-- LVSP v1.1: Provincial Veterinary Reporting & National Consolidation.
-- Source design is derived from the user-provided 2026 DVS consolidated Excel workbook
-- and provincial weekly/monthly reports. Additive/non-destructive.
-- Provincial names below are working reporting configuration only; they are not a replacement
-- for an officially imported master.admin_unit geography dataset.

CREATE SCHEMA IF NOT EXISTS reporting;

CREATE TABLE reporting.region (
  region_code VARCHAR(30) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reporting.region(region_code,name_lo,name_en,display_order) VALUES
 ('NORTH','ພາກເໜືອ','Northern Region',10),
 ('CENTRAL','ພາກກາງ','Central Region',20),
 ('SOUTH','ພາກໃຕ້','Southern Region',30)
ON CONFLICT (region_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,display_order=EXCLUDED.display_order,is_active=TRUE;

CREATE TABLE reporting.province_profile (
  province_code VARCHAR(40) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  region_code VARCHAR(30) REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
  display_order INTEGER NOT NULL DEFAULT 0,
  source_note TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reporting_province_region ON reporting.province_profile(region_code,status,display_order);

INSERT INTO reporting.province_profile(province_code,name_lo,name_en,region_code,display_order,source_note) VALUES
 ('PHONGSALY','ຜົ້ງສາລີ','Phongsaly','NORTH',1,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('LUANG_NAMTHA','ຫຼວງນ້ຳທາ','Luang Namtha','NORTH',2,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('OUDOMXAY','ອຸດົມໄຊ','Oudomxay','NORTH',3,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('BOKEO','ບໍ່ແກ້ວ','Bokeo','NORTH',4,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('LUANG_PRABANG','ຫຼວງພະບາງ','Luang Prabang','NORTH',5,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('HOUAPHANH','ຫົວພັນ','Houaphanh','NORTH',6,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XAYABOULY','ໄຊຍະບູລີ','Xayabouly','NORTH',7,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('VIENTIANE_CAPITAL','ນະຄອນຫຼວງວຽງຈັນ','Vientiane Capital','CENTRAL',8,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XIENG_KHOUANG','ຊຽງຂວາງ','Xieng Khouang','CENTRAL',9,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('VIENTIANE_PROVINCE','ວຽງຈັນ','Vientiane Province','CENTRAL',10,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('BOLIKHAMXAY','ບໍລິຄຳໄຊ','Bolikhamxay','CENTRAL',11,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('KHAMMOUANE','ຄຳມ່ວນ','Khammouane','CENTRAL',12,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SAVANNAKHET','ສະຫວັນນະເຂດ','Savannakhet','CENTRAL',13,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XAYSOMBOUN','ໄຊສົມບູນ','Xaysomboun','CENTRAL',14,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SALAVAN','ສາລະວັນ','Salavan','SOUTH',15,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SEKONG','ເຊກອງ','Sekong','SOUTH',16,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('CHAMPASAK','ຈຳປາສັກ','Champasak','SOUTH',17,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('ATTAPEU','ອັດຕະປື','Attapeu','SOUTH',18,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.')
ON CONFLICT (province_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,region_code=EXCLUDED.region_code,display_order=EXCLUDED.display_order,updated_at=now();

CREATE TABLE reporting.region_staff_assignment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_code VARCHAR(30) NOT NULL REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  staff_subject TEXT NOT NULL,
  staff_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  assignment_role VARCHAR(30) NOT NULL DEFAULT 'DATA_ENTRY',
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_assignment_role CHECK(assignment_role IN ('DATA_ENTRY','REVIEWER','MANAGER')),
  CONSTRAINT ck_reporting_assignment_dates CHECK(effective_to IS NULL OR effective_to>=effective_from)
);
CREATE INDEX idx_reporting_staff_subject ON reporting.region_staff_assignment(staff_subject,status,region_code);
CREATE UNIQUE INDEX uq_reporting_active_staff_region_role ON reporting.region_staff_assignment(region_code,staff_subject,assignment_role) WHERE status='ACTIVE' AND effective_to IS NULL;

CREATE TABLE reporting.report_submission (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  province_code VARCHAR(40) NOT NULL REFERENCES reporting.province_profile(province_code) ON DELETE RESTRICT,
  report_type VARCHAR(30) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  revision_no INTEGER NOT NULL DEFAULT 1 CHECK(revision_no>0),
  supersedes_report_id UUID REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  source_channel VARCHAR(40) NOT NULL DEFAULT 'DOCUMENT',
  source_format VARCHAR(30),
  source_filename TEXT,
  source_reference TEXT,
  source_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  received_by_subject TEXT,
  assigned_region_code VARCHAR(30) REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  assigned_to_subject TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
  include_in_consolidation BOOLEAN NOT NULL DEFAULT TRUE,
  summary_note TEXT,
  data_entry_note TEXT,
  ready_for_review_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  verified_by_subject TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_period CHECK(period_end>=period_start),
  CONSTRAINT ck_reporting_type CHECK(report_type IN ('WEEKLY','MONTHLY','QUARTERLY','SEMI_ANNUAL','ANNUAL','AD_HOC')),
  CONSTRAINT ck_reporting_status CHECK(status IN ('RECEIVED','DATA_ENTRY','READY_FOR_REVIEW','VERIFIED','REJECTED','SUPERSEDED')),
  CONSTRAINT ck_reporting_channel CHECK(source_channel IN ('DOCUMENT','EMAIL','PAPER','WHATSAPP','MESSAGING','DIRECT_ENTRY','OTHER'))
);
CREATE INDEX idx_reporting_submission_period ON reporting.report_submission(period_start,period_end,status);
CREATE INDEX idx_reporting_submission_province ON reporting.report_submission(province_code,period_end DESC,status);
CREATE INDEX idx_reporting_submission_assigned ON reporting.report_submission(assigned_to_subject,status,period_end DESC);
CREATE UNIQUE INDEX uq_reporting_submission_revision ON reporting.report_submission(province_code,report_type,period_start,period_end,revision_no);

CREATE TABLE reporting.indicator_definition (
  metric_code VARCHAR(100) PRIMARY KEY,
  section_code VARCHAR(60) NOT NULL,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  default_unit_code VARCHAR(30),
  aggregation_method VARCHAR(20) NOT NULL DEFAULT 'SUM',
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source_sheet TEXT,
  CONSTRAINT ck_reporting_aggregation CHECK(aggregation_method IN ('SUM','LATEST','AVERAGE','NONE'))
);

INSERT INTO reporting.indicator_definition(metric_code,section_code,name_lo,name_en,default_unit_code,display_order,source_sheet) VALUES
 ('VACCINATION.POPULATION','VACCINATION','ຈຳນວນຝູງສັດ','Animal population','HEAD',10,'1. ສັກຢາປ້ອງກັນສັດ'),
 ('VACCINATION.VACCINATED','VACCINATION','ຈຳນວນສັກຢາໄດ້','Animals vaccinated','HEAD',20,'1. ສັກຢາປ້ອງກັນສັດ'),
 ('TREATMENT.TREATED','TREATMENT','ຈຳນວນສັດປິ່ນປົວ','Animals treated','HEAD',30,'2. ປິ່ນປົວສັດ'),
 ('TREATMENT.DEATHS','TREATMENT','ຈຳນວນສັດຕາຍ','Animal deaths','HEAD',40,'2. ປິ່ນປົວສັດ'),
 ('SLAUGHTER.INSPECTED','SLAUGHTER_INSPECTION','ຈຳນວນສັດກວດກາກ່ອນ/ຫຼັງຂ້າ','Animals slaughtered/inspected','HEAD',50,'11. ອະນາໄມຊີ້ນຂ້າສັດ ບໍລິໂພກ')
ON CONFLICT (metric_code) DO NOTHING;

CREATE TABLE reporting.indicator_value (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  metric_code VARCHAR(100) NOT NULL REFERENCES reporting.indicator_definition(metric_code) ON DELETE RESTRICT,
  species_code VARCHAR(60) NOT NULL DEFAULT 'ALL',
  dimension_key VARCHAR(120) NOT NULL DEFAULT '',
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  value_numeric NUMERIC(20,4) NOT NULL DEFAULT 0,
  unit_code VARCHAR(30),
  source_note TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reporting_indicator UNIQUE(report_id,metric_code,species_code,dimension_key)
);
CREATE INDEX idx_reporting_indicator_metric ON reporting.indicator_value(metric_code,species_code,report_id);

CREATE TABLE reporting.trade_stat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  movement_type VARCHAR(20) NOT NULL,
  commodity_class VARCHAR(40) NOT NULL,
  purpose_code VARCHAR(40),
  item_name TEXT,
  species_code VARCHAR(60),
  checkpoint_in TEXT,
  checkpoint_out TEXT,
  origin_text TEXT,
  destination_text TEXT,
  company_name TEXT,
  transport_mode TEXT,
  quantity NUMERIC(20,4),
  unit_code VARCHAR(30),
  weight_ton NUMERIC(20,4),
  value_amount NUMERIC(20,2),
  currency_code VARCHAR(10) NOT NULL DEFAULT 'USD',
  source_note TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_trade_movement CHECK(movement_type IN ('IMPORT','EXPORT','TRANSIT','DOMESTIC_MOVEMENT')),
  CONSTRAINT ck_reporting_trade_class CHECK(commodity_class IN ('LIVE_ANIMAL','ANIMAL_PRODUCT','EGG','ANIMAL_BYPRODUCT','AQUATIC_ANIMAL','OTHER')),
  CONSTRAINT ck_reporting_trade_status CHECK(status IN ('ACTIVE','VOID'))
);
CREATE INDEX idx_reporting_trade_report ON reporting.trade_stat(report_id,status);
CREATE INDEX idx_reporting_trade_movement ON reporting.trade_stat(movement_type,commodity_class,currency_code);

CREATE TABLE reporting.activity_note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  note_type VARCHAR(30) NOT NULL DEFAULT 'ACTIVITY',
  category_code VARCHAR(60),
  title TEXT,
  description TEXT NOT NULL,
  result_text TEXT,
  is_next_period_plan BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_note_type CHECK(note_type IN ('ACTIVITY','ISSUE','RISK','PLAN','OTHER'))
);
CREATE INDEX idx_reporting_activity_report ON reporting.activity_note(report_id,status,note_type);

CREATE TABLE reporting.monthly_report_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_year INTEGER NOT NULL CHECK(report_year BETWEEN 2000 AND 2200),
  report_month INTEGER NOT NULL CHECK(report_month BETWEEN 1 AND 12),
  title_lo TEXT,
  narrative_lo TEXT,
  figures_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  created_by_subject TEXT,
  reviewed_by_subject TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reporting_monthly_draft UNIQUE(report_year,report_month),
  CONSTRAINT ck_reporting_monthly_draft_status CHECK(status IN ('DRAFT','REVIEWED','FINAL'))
);

INSERT INTO system.platform_setting(setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable)
VALUES ('REPORTING_MODULE_ENABLED','MODULES','ເປີດ Module ລາຍງານແຂວງ','Provincial reporting module enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE)
ON CONFLICT (setting_code) DO NOTHING;

INSERT INTO security.permission(code,description) VALUES
 ('reporting.read','View provincial veterinary reports and national consolidation'),
 ('reporting.enter','Register incoming provincial reports and enter required indicators'),
 ('reporting.verify','Review and verify provincial reporting data'),
 ('reporting.admin','Configure regional work allocation for provincial reporting')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN' AND p.code LIKE 'reporting.%'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('reporting.read','reporting.enter')
WHERE r.code IN ('DATA_STEWARD','EPIDEMIOLOGIST')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('reporting.read','reporting.verify')
WHERE r.code IN ('TECHNICAL_REVIEWER','MANAGEMENT_VIEWER')
ON CONFLICT DO NOTHING;
