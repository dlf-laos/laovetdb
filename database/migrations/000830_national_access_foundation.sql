-- LVSP v1.8 — National Access Foundation
-- Additive foundation for Central → Province → District → Checkpoint rollout,
-- public module roadmap/catalog, scoped staff assignments, and establishment licensing policy metadata.
-- This migration does NOT assign legal issuing authority. Authority rules remain DRAFT until formally approved.

CREATE TABLE IF NOT EXISTS system.module_catalog (
  module_code VARCHAR(100) PRIMARY KEY,
  module_key VARCHAR(100) UNIQUE,
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  description_lo TEXT,
  description_en TEXT,
  icon VARCHAR(20),
  delivery_status VARCHAR(30) NOT NULL DEFAULT 'PLANNED'
    CHECK(delivery_status IN ('ACTIVE','IN_DEVELOPMENT','PLANNED','PAUSED','RETIRED')),
  public_visible BOOLEAN NOT NULL DEFAULT TRUE,
  login_required BOOLEAN NOT NULL DEFAULT TRUE,
  public_data_mode VARCHAR(30) NOT NULL DEFAULT 'CATALOG_ONLY'
    CHECK(public_data_mode IN ('NONE','CATALOG_ONLY','READ_ONLY')),
  display_order INTEGER NOT NULL DEFAULT 1000,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_module_catalog_public
  ON system.module_catalog(public_visible,delivery_status,display_order);
DROP TRIGGER IF EXISTS trg_module_catalog_updated_at ON system.module_catalog;
CREATE TRIGGER trg_module_catalog_updated_at
  BEFORE UPDATE ON system.module_catalog
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

INSERT INTO system.module_catalog(module_code,module_key,name_lo,name_en,description_lo,description_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order) VALUES
('VET_DRUG_REGISTRATION','drug_registrations','ຂຶ້ນທະບຽນຢາສັດ','Veterinary Drug Registration','ທະບຽນຢາສັດ ແລະ ການກວດສອບສະຖານະທະບຽນ','Veterinary drug registration and public registry','💊','ACTIVE',TRUE,TRUE,'READ_ONLY',10),
('VET_DRUG_TRADE','trade_workspace','ນຳເຂົ້າ · ສົ່ງອອກ · ສົ່ງຜ່ານ','Import · Export · Transit','ຄຳຮ້ອງ ໃບອະນຸມັດ ການຜ່ານດ່ານ ແລະ ANIMUSE','Applications, permits, border clearance and ANIMUSE','🚚','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',20),
('CENTRAL_REPORTS','regulatory_reports','ສູນລາຍງານ','Central Reports','ລາຍງານກຳກັບດູແລ ແລະ ສະຖິຕິກາງ','Central regulatory reports and statistics','📈','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',30),
('COMPANY_MASTER','companies','ບໍລິສັດ / ຜູ້ປະກອບການ','Companies & Operators','ທະບຽນຜູ້ປະກອບການກາງ','Shared operator registry','🏢','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',40),
('PRODUCT_MASTER','products','ຖານຂໍ້ມູນຜະລິດຕະພັນ','Product Master','ຂໍ້ມູນຜະລິດຕະພັນກາງທີ່ໃຊ້ຮ່ວມກັນ','Shared product master data','🧬','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',50),
('ESTABLISHMENT_LICENSING','establishment_licensing','ອະນຸຍາດຮ້ານຢາ ແລະ ສະຖານປິ່ນປົວສັດ','Veterinary Establishment Licensing','ຮ້ານຂາຍຢາ/ອຸປະກອນສັດ ຫ້ອງປິ່ນປົວ ຄລີນິກ ແລະ ໂຮງໝໍສັດ','Veterinary pharmacies, treatment rooms, clinics and hospitals','🏥','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',60),
('BORDER_CLEARANCE','trade_shipments','ວຽກດ່ານ ແລະ ການກວດປ່ອຍ','Checkpoint & Border Clearance','ກວດໃບອະນຸຍາດ QR ການກວດທາງກາຍະພາບ ແລະ ບັນທຶກປະລິມານຈິງ','Permit verification, inspection and actual clearance records','🛂','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',70),
('INSPECTION','inspections','ການກວດກາ','Inspection & Compliance','ການກວດສະຖານທີ່ ການກວດຕິດຕາມ ແລະ compliance','Facility inspection, follow-up and compliance','🔎','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',80),
('VETERINARY_DEVICES','veterinary_devices','ອຸປະກອນສັດຕະວະແພດ','Veterinary Devices','ການຂຶ້ນທະບຽນ/ຄຸ້ມຄອງອຸປະກອນສັດຕະວະແພດ','Veterinary device registration and control','🩺','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',90),
('LABORATORY','laboratory_samples','ຫ້ອງວິໄຈ','Laboratory / LIMS','ຮັບຕົວຢ່າງ ກວດ ແລະ ລາຍງານຜົນ','Sample intake, testing and results','🧪','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',100),
('DISEASE_SURVEILLANCE','disease_cases','ເຝົ້າລະວັງພະຍາດ','Disease Surveillance','ລາຍງານເຫດສົງໄສ ການສືບສວນ ແລະ ຕິດຕາມພະຍາດ','Suspect reports, investigation and disease follow-up','🦠','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',110),
('GIS','gis_layers','ແຜນທີ່ GIS','GIS','ແຜນທີ່ສະຖານທີ່ ດ່ານ ຟາມ ແລະ ຂໍ້ມູນວິເຄາະ','Maps for facilities, checkpoints, farms and analysis','🗺️','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',120),
('ANIMAL_FEED_TRADE','animal_feed_trade','ອາຫານສັດ ແລະ ວັດຖຸດິບ','Animal Feed & Ingredients','ນຳເຂົ້າ ສົ່ງອອກ ສົ່ງຜ່ານ ແລະ ການອະນຸຍາດອາຫານສັດ','Feed and ingredient import, export, transit and licensing','🌾','PLANNED',TRUE,TRUE,'CATALOG_ONLY',200),
('ANIMAL_PRODUCT_TRADE','animal_product_trade','ສັດ ແລະ ຜະລິດຕະພັນສັດ','Animals & Animal Products','ນຳເຂົ້າ ສົ່ງອອກ ສົ່ງຜ່ານ ແລະ health certificate','Animal/product trade permits and health certificates','🐄','PLANNED',TRUE,TRUE,'CATALOG_ONLY',210),
('FARM_REGISTRATION','farm_registration','ຂຶ້ນທະບຽນຟາມ','Farm Registration','ທະບຽນຟາມ ຜູ້ລ້ຽງ ສະຖານທີ່ ແລະ ການຮັບຮອງ','Farm, operator and certification registry','🏡','PLANNED',TRUE,TRUE,'CATALOG_ONLY',220),
('SLAUGHTERHOUSE','slaughterhouse','ໂຮງຂ້າສັດ','Slaughterhouse','ທະບຽນ ອະນຸຍາດ ແລະ ກວດກາໂຮງຂ້າສັດ','Slaughterhouse registration, licensing and inspection','🏭','PLANNED',TRUE,TRUE,'CATALOG_ONLY',230),
('WET_MARKET','wet_market','ຕະຫຼາດສັດ/ຜະລິດຕະພັນ','Animal & Wet Markets','ທະບຽນ ກວດກາ ແລະ ຄຸ້ມຄອງຕະຫຼາດ','Market registration, inspection and monitoring','🏪','PLANNED',TRUE,TRUE,'CATALOG_ONLY',240),
('COMPLAINTS_GUIDANCE','complaints_guidance','ຄຳຮ້ອງ ຄຳແນະນຳ ແລະ ສອບຖາມ','Complaints, Guidance & Requests','ຮັບຄຳຮ້ອງ ສອບຖາມ ແລະ ຄູ່ມືບໍລິການ','Complaints, inquiries and service guidance','💬','PLANNED',TRUE,FALSE,'CATALOG_ONLY',250)
ON CONFLICT(module_code) DO NOTHING;

ALTER TABLE security.access_scope
  ADD COLUMN IF NOT EXISTS scope_name TEXT,
  ADD COLUMN IF NOT EXISTS scope_type VARCHAR(30) NOT NULL DEFAULT 'CUSTOM',
  ADD COLUMN IF NOT EXISTS facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;

ALTER TABLE security.access_scope DROP CONSTRAINT IF EXISTS ck_scope_target;
ALTER TABLE security.access_scope
  ADD CONSTRAINT ck_scope_target CHECK(
    is_global OR organization_id IS NOT NULL OR admin_unit_id IS NOT NULL OR facility_id IS NOT NULL OR domain_code IS NOT NULL
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='ck_access_scope_type' AND conrelid='security.access_scope'::regclass
  ) THEN
    ALTER TABLE security.access_scope ADD CONSTRAINT ck_access_scope_type CHECK(
      scope_type IN ('GLOBAL','CENTRAL','PROVINCE','DISTRICT','CHECKPOINT','ORGANIZATION','DOMAIN','CUSTOM')
    );
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_access_scope_admin_unit ON security.access_scope(admin_unit_id);
CREATE INDEX IF NOT EXISTS idx_access_scope_organization ON security.access_scope(organization_id);
CREATE INDEX IF NOT EXISTS idx_access_scope_facility ON security.access_scope(facility_id);

INSERT INTO security.role(code,name_lo,name_en,is_system_role,is_active) VALUES
('PROVINCIAL_ADMIN','ຜູ້ຄຸ້ມຄອງລະບົບລະດັບແຂວງ','Provincial Administrator',TRUE,TRUE),
('PROVINCIAL_LICENSING_OFFICER','ພະນັກງານອະນຸຍາດລະດັບແຂວງ','Provincial Licensing Officer',TRUE,TRUE),
('DISTRICT_LICENSING_OFFICER','ພະນັກງານອະນຸຍາດລະດັບເມືອງ','District Licensing Officer',TRUE,TRUE),
('DISTRICT_INSPECTOR','ພະນັກງານກວດກາລະດັບເມືອງ','District Inspector',TRUE,TRUE),
('CHECKPOINT_SUPERVISOR','ຫົວໜ້າ/ຜູ້ກວດກາດ່ານ','Checkpoint Supervisor',TRUE,TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO security.permission(code,description) VALUES
('security.scope.manage','Manage organization/geographic/checkpoint access scopes'),
('establishment.read','Read veterinary establishment licensing data'),
('establishment.write','Create/update establishment applications and working records'),
('establishment.inspect','Record establishment site inspections'),
('establishment.review','Review establishment licensing applications'),
('establishment.approve','Approve establishment licensing decisions where legally delegated'),
('checkpoint.read','Read checkpoint-bound permits and shipment records'),
('checkpoint.clear','Record border clearance/release actions'),
('checkpoint.hold','Record border hold/rejection actions'),
('module.catalog.manage','Manage public module roadmap/catalog')
ON CONFLICT(code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect','establishment.review','establishment.approve','report.read')
WHERE r.code='PROVINCIAL_ADMIN' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect','establishment.review','report.read')
WHERE r.code='PROVINCIAL_LICENSING_OFFICER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect')
WHERE r.code='DISTRICT_LICENSING_OFFICER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.inspect')
WHERE r.code='DISTRICT_INSPECTOR' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','trade.read','trade.write','checkpoint.read','checkpoint.clear','checkpoint.hold')
WHERE r.code IN ('BORDER_OFFICER','QUARANTINE_OFFICER','CHECKPOINT_SUPERVISOR')
ON CONFLICT DO NOTHING;

INSERT INTO lookup.facility_type(code,name_lo,name_en,is_active) VALUES
('BORDER_CHECKPOINT','ດ່ານກວດກາສັດຕະວະແພດ','Veterinary Border Checkpoint',TRUE),
('VET_DRUG_EQUIPMENT_SHOP','ຮ້ານຂາຍຢາສັດ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Drug & Equipment Shop',TRUE),
('VET_TREATMENT_ROOM','ຫ້ອງປິ່ນປົວສັດ','Veterinary Treatment Room',TRUE),
('VET_CLINIC','ຄລີນິກສັດ','Veterinary Clinic',TRUE),
('VET_HOSPITAL','ໂຮງໝໍສັດ','Veterinary Hospital',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO licensing.license_type(code,name_lo,name_en,is_active) VALUES
('VET_DRUG_EQUIPMENT_SHOP','ໃບອະນຸຍາດຮ້ານຂາຍຢາສັດ ແລະ ອຸປະກອນ','Veterinary Drug & Equipment Shop License',TRUE),
('VET_TREATMENT_ROOM','ໃບອະນຸຍາດຫ້ອງປິ່ນປົວສັດ','Veterinary Treatment Room License',TRUE),
('VET_CLINIC','ໃບອະນຸຍາດຄລີນິກສັດ','Veterinary Clinic License',TRUE),
('VET_HOSPITAL','ໃບອະນຸຍາດໂຮງໝໍສັດ','Veterinary Hospital License',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

CREATE TABLE IF NOT EXISTS licensing.license_authority_rule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_type_id UUID NOT NULL REFERENCES licensing.license_type(id) ON DELETE RESTRICT,
  establishment_class_code VARCHAR(60),
  issuing_level VARCHAR(30) NOT NULL CHECK(issuing_level IN ('CENTRAL','PROVINCE','DISTRICT')),
  review_level VARCHAR(30) CHECK(review_level IS NULL OR review_level IN ('CENTRAL','PROVINCE','DISTRICT')),
  admin_unit_type_code VARCHAR(30),
  legal_reference TEXT,
  effective_from DATE,
  effective_to DATE,
  policy_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT' CHECK(policy_status IN ('DRAFT','APPROVED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_license_authority_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from)
);
CREATE INDEX IF NOT EXISTS idx_license_authority_rule_type ON licensing.license_authority_rule(license_type_id,policy_status);
DROP TRIGGER IF EXISTS trg_license_authority_rule_updated_at ON licensing.license_authority_rule;
CREATE TRIGGER trg_license_authority_rule_updated_at BEFORE UPDATE ON licensing.license_authority_rule
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
COMMENT ON TABLE licensing.license_authority_rule IS
'Controlled delegation matrix. DRAFT rows are not legal authority; only formally approved rules should drive issuance.';

CREATE OR REPLACE VIEW analytics.v_user_access_matrix AS
SELECT
  ura.id AS assignment_id,
  u.id AS user_id,
  u.username,
  u.email,
  u.status AS user_status,
  r.code AS role_code,
  r.name_lo AS role_name_lo,
  r.name_en AS role_name_en,
  s.id AS access_scope_id,
  s.scope_name,
  s.scope_type,
  s.is_global,
  s.domain_code,
  s.organization_id,
  o.organization_code,
  o.name_lo AS organization_name_lo,
  o.name_en AS organization_name_en,
  s.admin_unit_id,
  au.official_code AS admin_unit_code,
  au.name_lo AS admin_unit_name_lo,
  au.name_en AS admin_unit_name_en,
  aut.code AS admin_unit_type_code,
  s.facility_id,
  f.facility_no,
  f.name_lo AS facility_name_lo,
  f.name_en AS facility_name_en,
  ura.valid_from,
  ura.valid_to,
  ura.status AS assignment_status
FROM security.user_role_assignment ura
JOIN security.app_user u ON u.id=ura.user_id
JOIN security.role r ON r.id=ura.role_id
LEFT JOIN security.access_scope s ON s.id=ura.access_scope_id
LEFT JOIN master.organization o ON o.id=s.organization_id
LEFT JOIN master.admin_unit au ON au.id=s.admin_unit_id
LEFT JOIN lookup.admin_unit_type aut ON aut.id=au.admin_unit_type_id
LEFT JOIN master.facility f ON f.id=s.facility_id;
