-- LVSP v1.0: installable Web/PWA, central administration configuration and offline field capture staging.
-- Additive/non-destructive. Secrets must never be stored in system.platform_setting.

CREATE TABLE system.platform_setting (
  setting_code VARCHAR(120) PRIMARY KEY,
  category_code VARCHAR(60) NOT NULL DEFAULT 'GENERAL',
  name_lo TEXT NOT NULL,
  name_en TEXT,
  value_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  value_type VARCHAR(30) NOT NULL DEFAULT 'TEXT',
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  is_editable BOOLEAN NOT NULL DEFAULT TRUE,
  is_secret BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  CONSTRAINT ck_platform_setting_not_secret CHECK (is_secret = FALSE),
  CONSTRAINT ck_platform_setting_type CHECK (value_type IN ('TEXT','BOOLEAN','NUMBER','JSON'))
);
CREATE INDEX idx_platform_setting_category ON system.platform_setting(category_code,status);

INSERT INTO system.platform_setting(setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable)
VALUES
 ('APP_NAME_LO','BRANDING','ຊື່ລະບົບພາສາລາວ','Application name (Lao)',to_jsonb('ລະບົບບໍລິການສັດຕະວະແພດລາວ'::text),'TEXT',TRUE,TRUE),
 ('APP_NAME_EN','BRANDING','ຊື່ລະບົບພາສາອັງກິດ','Application name (English)',to_jsonb('Lao Veterinary Services Platform'::text),'TEXT',TRUE,TRUE),
 ('PUBLIC_SERVICE_CATALOG_ENABLED','PORTAL','ເປີດ Public Service Catalog','Public service catalog enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('STAFF_PWA_ENABLED','PWA','ເປີດ Staff PWA','Staff PWA enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('FIELD_PWA_ENABLED','PWA','ເປີດ Field PWA','Field PWA enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('MAINTENANCE_BANNER','PORTAL','ຂໍ້ຄວາມແຈ້ງບຳລຸງຮັກສາ','Maintenance banner',to_jsonb(''::text),'TEXT',TRUE,TRUE)
ON CONFLICT (setting_code) DO NOTHING;

CREATE TABLE inspection.field_capture_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local_capture_id VARCHAR(120) NOT NULL,
  submitted_by_subject TEXT NOT NULL,
  submitted_by_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  capture_type VARCHAR(60) NOT NULL DEFAULT 'FIELD_NOTE',
  facility_text TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  captured_at TIMESTAMPTZ NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  sync_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
  linked_inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  CONSTRAINT uq_field_capture_subject_local UNIQUE(submitted_by_subject,local_capture_id),
  CONSTRAINT ck_field_capture_lat CHECK(latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_field_capture_lon CHECK(longitude IS NULL OR longitude BETWEEN -180 AND 180)
);
CREATE INDEX idx_field_capture_status ON inspection.field_capture_draft(sync_status,received_at DESC);
CREATE INDEX idx_field_capture_inspection ON inspection.field_capture_draft(linked_inspection_case_id) WHERE linked_inspection_case_id IS NOT NULL;

-- Role permissions for safe central configuration. Existing SYSTEM_ADMIN/SECURITY_ADMIN continue to be enforced by API.
INSERT INTO security.permission(code,description) VALUES
 ('admin.platform.read','View LVSP platform administration and runtime configuration'),
 ('admin.platform.configure','Edit non-secret LVSP platform configuration'),
 ('admin.services.configure','Activate/deactivate or expose configured digital services'),
 ('field.capture.sync','Sync offline field capture drafts to LVSP')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN' AND p.code IN ('admin.platform.read','admin.platform.configure','admin.services.configure','field.capture.sync')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SECURITY_ADMIN' AND p.code IN ('admin.platform.read','admin.platform.configure')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code IN ('INSPECTOR','SENIOR_INSPECTOR') AND p.code='field.capture.sync'
ON CONFLICT DO NOTHING;
