-- LVSP v1.7 Phase 2
-- Individual database authentication + controlled role metadata.
-- Safe additive migration: no existing regulatory/trade data is changed.

ALTER TABLE security.app_user
  ADD COLUMN IF NOT EXISTS password_hash TEXT,
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS failed_login_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='ck_app_user_failed_login_count'
      AND conrelid='security.app_user'::regclass
  ) THEN
    ALTER TABLE security.app_user
      ADD CONSTRAINT ck_app_user_failed_login_count CHECK(failed_login_count>=0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_user_status
  ON security.app_user(status);

CREATE INDEX IF NOT EXISTS idx_app_user_locked_until
  ON security.app_user(locked_until)
  WHERE locked_until IS NOT NULL;

INSERT INTO security.role(code,name_lo,name_en,is_system_role,is_active) VALUES
  ('SYSTEM_ADMIN','ຜູ້ບໍລິຫານລະບົບ','System Administrator',TRUE,TRUE),
  ('SECURITY_ADMIN','ຜູ້ຄຸ້ມຄອງສິດຜູ້ໃຊ້','Security Administrator',TRUE,TRUE),
  ('DATA_STEWARD','ຜູ້ຄຸ້ມຄອງຂໍ້ມູນກາງ','Data Steward',TRUE,TRUE),
  ('REGISTRY_OFFICER','ພະນັກງານທະບຽນ','Registry Officer',TRUE,TRUE),
  ('TECHNICAL_REVIEWER','ພະນັກງານກວດດ້ານວິຊາການ','Technical Reviewer',TRUE,TRUE),
  ('APPROVING_AUTHORITY','ຜູ້ມີອຳນາດອະນຸມັດ','Approving Authority',TRUE,TRUE),
  ('BORDER_OFFICER','ພະນັກງານດ່ານ','Border Officer',TRUE,TRUE),
  ('QUARANTINE_OFFICER','ພະນັກງານກັກກັນ','Quarantine Officer',TRUE,TRUE),
  ('MANAGEMENT_VIEWER','ຜູ້ບໍລິຫານເບິ່ງລາຍງານ','Management Viewer',TRUE,TRUE)
ON CONFLICT(code) DO UPDATE SET
  name_lo=EXCLUDED.name_lo,
  name_en=EXCLUDED.name_en,
  is_active=TRUE;

INSERT INTO security.permission(code,description) VALUES
  ('public.read','Read public LVSP information'),
  ('veterinary_drug.read','Read veterinary drug registration data'),
  ('veterinary_drug.write','Create/update veterinary drug registration working data'),
  ('veterinary_drug.review','Review veterinary drug dossiers'),
  ('veterinary_drug.approve','Approve veterinary drug regulatory decisions'),
  ('trade.read','Read import/export/transit data'),
  ('trade.write','Create/update import/export/transit working data'),
  ('trade.review','Review import/export/transit applications'),
  ('trade.approve','Approve import/export/transit decisions'),
  ('master_data.read','Read shared master data'),
  ('master_data.write','Maintain shared master data'),
  ('report.read','Read regulatory/management reports'),
  ('security.user.manage','Manage LVSP user accounts and roles')
ON CONFLICT(code) DO NOTHING;

-- SYSTEM_ADMIN gets every permission.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

-- SECURITY_ADMIN controls identity/role administration.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('security.user.manage','public.read','report.read')
WHERE r.code='SECURITY_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.write','trade.read')
WHERE r.code='REGISTRY_OFFICER'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.review','trade.read','trade.review','report.read')
WHERE r.code='TECHNICAL_REVIEWER'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.approve','trade.read','trade.approve','report.read')
WHERE r.code='APPROVING_AUTHORITY'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','trade.read','trade.write')
WHERE r.code IN ('BORDER_OFFICER','QUARANTINE_OFFICER')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','master_data.read','master_data.write')
WHERE r.code='DATA_STEWARD'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','trade.read','master_data.read','report.read')
WHERE r.code='MANAGEMENT_VIEWER'
ON CONFLICT DO NOTHING;

COMMENT ON COLUMN security.app_user.password_hash IS
'LVSP application password verifier. Never expose via API or frontend.';
COMMENT ON COLUMN security.app_user.must_change_password IS
'Forces a newly provisioned/reset account to set a personal password before normal work.';
