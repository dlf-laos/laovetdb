-- LVSP v0.9.0 — Guided Digital Services + Workflow UX foundation
-- Purpose: turn the enterprise architecture into configuration-driven, step-by-step services.
-- Regulatory requirements below are a staging baseline and remain subject to official legal/domain verification.

CREATE TABLE IF NOT EXISTS system.service_guide (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL UNIQUE REFERENCES system.service_version(id) ON DELETE RESTRICT,
  category_code VARCHAR(60),
  icon VARCHAR(20),
  display_order INTEGER NOT NULL DEFAULT 100,
  overview_lo TEXT,
  overview_en TEXT,
  eligibility_lo TEXT,
  eligibility_en TEXT,
  preparation_lo TEXT,
  preparation_en TEXT,
  processing_lo TEXT,
  processing_en TEXT,
  launch_module_key VARCHAR(100),
  launch_action VARCHAR(40) NOT NULL DEFAULT 'CREATE',
  allow_public_browse BOOLEAN NOT NULL DEFAULT TRUE,
  requires_authentication BOOLEAN NOT NULL DEFAULT TRUE,
  configuration_notice_lo TEXT,
  configuration_notice_en TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'PILOT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_service_guide_order ON system.service_guide(status,display_order);
DROP TRIGGER IF EXISTS trg_service_guide_updated_at ON system.service_guide;
CREATE TRIGGER trg_service_guide_updated_at BEFORE UPDATE ON system.service_guide FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_step (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  step_code VARCHAR(80) NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no>0),
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  step_type VARCHAR(40) NOT NULL DEFAULT 'GUIDANCE',
  actor_scope VARCHAR(30) NOT NULL DEFAULT 'APPLICANT',
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,step_code),
  UNIQUE(service_version_id,sequence_no)
);
CREATE INDEX IF NOT EXISTS idx_service_step_version ON system.service_step(service_version_id,sequence_no);
DROP TRIGGER IF EXISTS trg_service_step_updated_at ON system.service_step;
CREATE TRIGGER trg_service_step_updated_at BEFORE UPDATE ON system.service_step FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_requirement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  requirement_code VARCHAR(100) NOT NULL,
  requirement_type VARCHAR(30) NOT NULL DEFAULT 'DOCUMENT',
  sequence_no INTEGER NOT NULL DEFAULT 100,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  condition_configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
  example_note_lo TEXT,
  example_note_en TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,requirement_code)
);
CREATE INDEX IF NOT EXISTS idx_service_requirement_version ON system.service_requirement(service_version_id,sequence_no);
DROP TRIGGER IF EXISTS trg_service_requirement_updated_at ON system.service_requirement;
CREATE TRIGGER trg_service_requirement_updated_at BEFORE UPDATE ON system.service_requirement FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_output (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  output_code VARCHAR(100) NOT NULL,
  output_type VARCHAR(50) NOT NULL,
  sequence_no INTEGER NOT NULL DEFAULT 100,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  template_code VARCHAR(100),
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,output_code)
);
CREATE INDEX IF NOT EXISTS idx_service_output_version ON system.service_output(service_version_id,sequence_no);

CREATE TABLE IF NOT EXISTS casework.service_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  service_code_snapshot VARCHAR(50) NOT NULL,
  applicant_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
  company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  started_by_subject TEXT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'IN_PROGRESS',
  current_step_code VARCHAR(80),
  target_resource VARCHAR(100),
  target_id UUID,
  draft_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_service_draft_subject ON casework.service_draft(started_by_subject,status,updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_draft_company ON casework.service_draft(company_id,status) WHERE company_id IS NOT NULL;
DROP TRIGGER IF EXISTS trg_service_draft_updated_at ON casework.service_draft;
CREATE TRIGGER trg_service_draft_updated_at BEFORE UPDATE ON casework.service_draft FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS casework.service_draft_step (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id UUID NOT NULL REFERENCES casework.service_draft(id) ON DELETE CASCADE,
  step_code VARCHAR(80) NOT NULL,
  sequence_no INTEGER NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'NOT_STARTED',
  step_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(draft_id,step_code)
);
CREATE INDEX IF NOT EXISTS idx_service_draft_step ON casework.service_draft_step(draft_id,sequence_no);

CREATE TABLE IF NOT EXISTS casework.service_draft_requirement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id UUID NOT NULL REFERENCES casework.service_draft(id) ON DELETE CASCADE,
  requirement_id UUID NOT NULL REFERENCES system.service_requirement(id) ON DELETE RESTRICT,
  status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  note TEXT,
  document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  checked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(draft_id,requirement_id)
);
CREATE INDEX IF NOT EXISTS idx_service_draft_requirement ON casework.service_draft_requirement(draft_id,status);

-- Priority services used by the v0.9 guided portal.
INSERT INTO system.service_definition(service_code,domain_code,name_lo,name_en,description,applicant_type,is_public,is_active) VALUES
('TR-1021','TR','ແຜນນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດປະຈຳປີ','Annual Veterinary Products Import Plan','Annual plan covering medicines, vaccines, biologicals and veterinary devices in one plan.','COMPANY',TRUE,TRUE),
('TR-1007','TR','ຄຳຮ້ອງນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Products Import Application','One import application may contain mixed veterinary medicines, vaccines, biologicals and veterinary devices.','COMPANY',TRUE,TRUE)
ON CONFLICT(service_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description=EXCLUDED.description,applicant_type=EXCLUDED.applicant_type,is_public=TRUE,is_active=TRUE;

UPDATE system.service_definition SET applicant_type='COMPANY',is_public=TRUE,is_active=TRUE WHERE service_code='VM-1003';

INSERT INTO system.service_version(service_id,version_no,effective_from,workflow_code,status)
SELECT id,1,now(),CASE WHEN service_code='VM-1003' THEN 'WF-003' ELSE 'WF-006' END,'DRAFT'
FROM system.service_definition WHERE service_code IN ('VM-1003','TR-1021','TR-1007')
ON CONFLICT(service_id,version_no) DO NOTHING;

-- Guide headers. These are operational guidance baselines, not a claim that every requirement is legally mandatory in every case.
WITH v AS (
  SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd
  JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
  WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
  SELECT * FROM (VALUES
  ('VM-1003','REGISTRATION','💊',10,
   'ຄູ່ມືຂຶ້ນທະບຽນຢາສັດຕະວະແພດແບບທີລະຂັ້ນ. ລະບົບຈະພາກວດຂໍ້ມູນບໍລິສັດ, ຜະລິດຕະພັນ, ໂຮງງານ, ຂະໜາດບັນຈຸ, ເອກະສານ ແລະ ການທົບທວນກ່ອນຍື່ນ.',
   'Step-by-step veterinary product registration guide covering company, product, manufacturing site, package presentations, supporting dossier and review before submission.',
   'ກ່ອນເລີ່ມ ໃຫ້ກວດວ່າບໍລິສັດ, ຜູ້ຖືທະບຽນ, ຜູ້ນຳເຂົ້າ ແລະ ໂຮງງານ/ສະຖານທີ່ຜະລິດ ຖືກສ້າງໃນ Company Master ແລ້ວ.',
   'Before starting, confirm that the relevant legal companies and their offices/manufacturing sites exist in Company Master.',
   'ກະກຽມຂໍ້ມູນຜະລິດຕະພັນ, ສູດ/ສ່ວນປະກອບ, ສະຫຼາກ/ໃບແນະນຳ, ຂໍ້ມູນຄຸນນະພາບ ແລະ ຫຼັກຖານ GMP/CPP ຕາມກໍລະນີທີ່ນຳໃຊ້.',
   'Prepare product information, composition, labeling/leaflet, quality information and GMP/CPP evidence where applicable.',
   'ຫຼັງຍື່ນ ຄຳຮ້ອງຈະເຂົ້າຂັ້ນກວດຄວາມຄົບຖ້ວນ, ກວດວິຊາການ, ຕັດສິນ ແລະ ອອກເອກະສານຕາມ workflow ທີ່ປະກາດໃຊ້.',
   'After submission, the case moves through admissibility, technical review, decision and document issuance according to the published workflow.',
   'drug_registrations'),
  ('TR-1021','TRADE','📅',20,
   'ສ້າງແຜນນຳເຂົ້າປະຈຳປີ 1 ແຜນ ທີ່ຮອງຮັບຢາ, ວັກຊີນ, ຊີວະພັນ ແລະ ອຸປະກອນສັດຕະວະແພດນຳກັນ. ລາຍການຈຳນວນຫຼາຍສາມາດນຳເຂົ້າຈາກ Excel.',
   'Create one annual plan that may contain medicines, vaccines, biologicals and veterinary devices together, with Excel bulk import for large item lists.',
   'ກວດ Company Master ແລະ ສະຖານທີ່ຂອງຜູ້ປະກອບການກ່ອນ.',
   'Confirm the operator legal company and submitting office/site first.',
   'ກະກຽມປີແຜນ, ລາຍການສິນຄ້າ, ທະບຽນ/ຂະໜາດບັນຈຸທີ່ກ່ຽວຂ້ອງ, ຈຳນວນ, ຫົວໜ່ວຍ ແລະ ມູນຄ່າຖ້າມີ.',
   'Prepare plan year, items, relevant registration/package reference, quantities, units and values when available.',
   'ລະບົບຈະກວດລາຍການ ແລະ ຮັກສາແຜນເປັນຖານອ້າງອີງສຳລັບຄຳຮ້ອງນຳເຂົ້າແຕ່ລະຄັ້ງ.',
   'The approved/accepted plan becomes a reference for subsequent import applications as configured.',
   'import_plans'),
  ('TR-1007','TRADE','🚚',30,
   'ຄຳຮ້ອງນຳເຂົ້າ 1 ໃບສາມາດມີຢາ ແລະ ອຸປະກອນສັດຕະວະແພດນຳກັນ. ລະບົບຈະຊ່ວຍກວດການຂຶ້ນທະບຽນ, ຂະໜາດບັນຈຸ, ແຜນປະຈຳປີ ແລະ AMR/ANIMUSE ຕາມຂໍ້ມູນທີ່ມີ.',
   'One import application may contain mixed veterinary medicines and devices. LVSP guides registration/package, annual-plan and AMR/ANIMUSE checks using available data.',
   'ກ່ອນຍື່ນ ກວດ Company/Site, ແຜນປະຈຳປີທີ່ກ່ຽວຂ້ອງ ແລະ ຂໍ້ມູນສິນຄ້າ.',
   'Before submission, confirm Company/Site, the relevant annual plan and item master data.',
   'ກະກຽມ Invoice, ປະເທດຕົ້ນທາງ, ດ່ານ, ຈຸດປະສົງ ແລະ ລາຍການສິນຄ້າ. ສາມາດໃຊ້ Excel ເມື່ອມີຫຼາຍລາຍການ.',
   'Prepare invoice, origin, checkpoint, purpose and item details. Use Excel bulk import for large applications.',
   'ຫຼັງຍື່ນ ຕິດຕາມສະຖານະຈາກຮັບຄຳຮ້ອງ → ກວດ → ອະນຸມັດ/ອອກໃບ → ຜ່ານດ່ານ → ປິດແຟ້ມ ຕາມ workflow ທີ່ກຳນົດ.',
   'Track the case from receipt through review, authorization/document issuance, border processing and closure according to the configured workflow.',
   'import_applications')
  ) AS t(service_code,category_code,icon,display_order,overview_lo,overview_en,eligibility_lo,eligibility_en,preparation_lo,preparation_en,processing_lo,processing_en,launch_module_key)
)
INSERT INTO system.service_guide(service_version_id,category_code,icon,display_order,overview_lo,overview_en,eligibility_lo,eligibility_en,preparation_lo,preparation_en,processing_lo,processing_en,launch_module_key,configuration_notice_lo,configuration_notice_en,status)
SELECT v.service_version_id,x.category_code,x.icon,x.display_order,x.overview_lo,x.overview_en,x.eligibility_lo,x.eligibility_en,x.preparation_lo,x.preparation_en,x.processing_lo,x.processing_en,x.launch_module_key,
'ຂໍ້ກຳນົດ/ເອກະສານໃນໜ້ານີ້ແມ່ນ configuration ສຳລັບ Staging/Pilot. ກ່ອນ Production ຕ້ອງກວດຢືນຢັນກັບນິຕິກຳ ແລະ SOP ທາງການ.',
'Requirements shown here are staging/pilot configuration and must be verified against official legal instruments and SOPs before production.','PILOT'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id) DO UPDATE SET category_code=EXCLUDED.category_code,icon=EXCLUDED.icon,display_order=EXCLUDED.display_order,overview_lo=EXCLUDED.overview_lo,overview_en=EXCLUDED.overview_en,eligibility_lo=EXCLUDED.eligibility_lo,eligibility_en=EXCLUDED.eligibility_en,preparation_lo=EXCLUDED.preparation_lo,preparation_en=EXCLUDED.preparation_en,processing_lo=EXCLUDED.processing_lo,processing_en=EXCLUDED.processing_en,launch_module_key=EXCLUDED.launch_module_key,configuration_notice_lo=EXCLUDED.configuration_notice_lo,configuration_notice_en=EXCLUDED.configuration_notice_en,status='PILOT';

-- Steps are intentionally operational and configurable. They do not hard-code approval authority or legal time limits.
WITH v AS (
  SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
  WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company Master, ບົດບາດຜູ້ຖືທະບຽນ/ຜູ້ນຳເຂົ້າ ແລະ ໂຮງງານ/ສະຖານທີ່.','Confirm legal companies, roles and physical sites before entering the product.','GUIDANCE','APPLICANT','{}'),
 ('VM-1003','PRODUCT_CORE',20,'ຂໍ້ມູນຜະລິດຕະພັນ','Product core','ປ້ອນ Trade name, generic/INN, category, dosage form, target species, route, indications, dosage, shelf life ແລະ storage.','Enter product identity and clinical/quality summary fields.','FORM','APPLICANT','{"section":"product"}'),
 ('VM-1003','PARTIES_SITES',30,'ບໍລິສັດ ແລະ ສະຖານທີ່','Companies and sites','ເລືອກ Registration Holder, Importer, Manufacturer, Distributor ແລະ site ທີ່ຖືກຕ້ອງ.','Select each legal company and the correct role-specific site.','FORM','APPLICANT','{"section":"parties"}'),
 ('VM-1003','PRESENTATIONS',40,'ຂະໜາດບັນຈຸ ແລະ ສ່ວນປະກອບ','Package presentations and composition','ເພີ່ມທຸກ presentation. 1 product ສາມາດມີຫຼາຍຂະໜາດ ແລະຮັກສາ composition ຕາມ presentation.','Add all presentations and presentation-level composition.','FORM','APPLICANT','{"section":"presentations"}'),
 ('VM-1003','DOSSIER',50,'ເອກະສານປະກອບ','Supporting dossier','ກວດ checklist ຂອງເອກະສານທີ່ກຳນົດໄວ້ສຳລັບ service version ນີ້.','Review the configured supporting-document checklist.','DOCUMENTS','APPLICANT','{}'),
 ('VM-1003','REVIEW',60,'ກວດຄືນກ່ອນຍື່ນ','Review before submission','ກວດຊື່, ສູດ, package, company/site ແລະເອກະສານໃຫ້ຄົບ.','Review product, packages, parties/sites and documents.','REVIEW','APPLICANT','{}'),
 ('VM-1003','SUBMIT',70,'ຢືນຢັນ ແລະ ຍື່ນ','Declare and submit','ຢືນຢັນຄວາມຖືກຕ້ອງ ແລະສົ່ງເຂົ້າ workflow.','Confirm accuracy and submit into the configured workflow.','DECLARATION','APPLICANT','{}'),
 ('VM-1003','PROCESSING',80,'ຕິດຕາມການດຳເນີນ','Track processing','ຕິດຕາມການກວດຄວາມຄົບຖ້ວນ, ກວດວິຊາການ, ການຕັດສິນ ແລະ ອອກເອກະສານ.','Track admissibility, technical review, decision and document issuance.','TRACKING','SYSTEM','{}'),

 ('TR-1021','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company Master ແລະ site ທີ່ຈະໃຊ້ຍື່ນແຜນ.','Confirm the company and submitting site.','GUIDANCE','APPLICANT','{}'),
 ('TR-1021','PLAN_HEADER',20,'ຂໍ້ມູນແຜນ','Plan header','ກຳນົດປີ, ບໍລິສັດ, site, ວັນທີຍື່ນ ແລະເລກອ້າງອີງຕາມທີ່ລະບົບກຳນົດ.','Set plan year, company, site, application date and reference fields.','FORM','APPLICANT','{"section":"plan_header"}'),
 ('TR-1021','ITEMS',30,'ເພີ່ມລາຍການ','Add items','ປ້ອນລາຍການເອງ ຫຼື Import Excel. ຢາ ແລະ ອຸປະກອນສາມາດຢູ່ໃນແຜນດຽວ.','Enter items manually or import Excel; medicines and devices may be in the same plan.','ITEMS','APPLICANT','{"bulk_excel":true,"template":"Annual_Import_Plan_Template.xlsx"}'),
 ('TR-1021','VALIDATE',40,'ກວດລາຍການ','Validate items','ລະບົບກວດ item type, registration/package link ແລະ validation message ຕາມຂໍ້ມູນທີ່ມີ.','Validate item types and available registration/package references.','SYSTEM_CHECK','SYSTEM','{}'),
 ('TR-1021','REVIEW',50,'ກວດຄືນແຜນ','Review plan','ກວດຈຳນວນລາຍການ, ປະລິມານ, ຫົວໜ່ວຍ ແລະມູນຄ່າກ່ອນຍື່ນ.','Review item count, quantities, units and values before submission.','REVIEW','APPLICANT','{}'),
 ('TR-1021','SUBMIT',60,'ຍື່ນແຜນ','Submit plan','ບັນທຶກ/ຍື່ນແຜນເຂົ້າລະບົບຕາມ workflow ທີ່ກຳນົດ.','Save/submit the plan according to configured workflow.','DECLARATION','APPLICANT','{}'),

 ('TR-1007','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company/Site, ແຜນປະຈຳປີ ແລະລາຍການ product/device master.','Confirm company/site, relevant annual plan and product/device master records.','GUIDANCE','APPLICANT','{}'),
 ('TR-1007','APPLICATION_HEADER',20,'ຂໍ້ມູນຄຳຮ້ອງ','Application header','ປ້ອນວັນທີ, company/site, plan, invoice, origin, checkpoint ແລະ purpose.','Enter application date, company/site, plan, invoice, origin, checkpoint and purpose.','FORM','APPLICANT','{"section":"import_header"}'),
 ('TR-1007','ITEMS',30,'ລາຍການນຳເຂົ້າ','Import items','ເພີ່ມລາຍການເອງ ຫຼື Import Excel. 1 ຄຳຮ້ອງສາມາດມີ mixed items.','Enter items manually or by Excel; one application may contain mixed items.','ITEMS','APPLICANT','{"bulk_excel":true,"template":"Import_Application_Items_Template.xlsx"}'),
 ('TR-1007','SYSTEM_CHECKS',40,'ກວດອັດຕະໂນມັດ','System checks','ກວດ registration status, package, annual plan reference ແລະ AMR/ANIMUSE fields ເທົ່າທີ່ຂໍ້ມູນຮອງຮັບ.','Check registration, package, annual-plan reference and AMR/ANIMUSE fields where data supports it.','SYSTEM_CHECK','SYSTEM','{}'),
 ('TR-1007','DOCUMENTS',50,'ເອກະສານປະກອບ','Supporting documents','ກວດ checklist ເອກະສານຕາມ service configuration.','Review the configured supporting-document checklist.','DOCUMENTS','APPLICANT','{}'),
 ('TR-1007','REVIEW',60,'ກວດຄືນ','Review','Preview ຄຳຮ້ອງ ແລະລາຍການທັງໝົດກ່ອນຍື່ນ.','Preview the full application and items before submission.','REVIEW','APPLICANT','{}'),
 ('TR-1007','SUBMIT',70,'ຢືນຢັນ ແລະ ຍື່ນ','Declare and submit','ຢືນຢັນ ແລະສົ່ງຄຳຮ້ອງເຂົ້າ workflow.','Confirm and submit the application into workflow.','DECLARATION','APPLICANT','{}'),
 ('TR-1007','PROCESSING',80,'ຕິດຕາມສະຖານະ','Track processing','ຕິດຕາມຮັບຄຳຮ້ອງ, ກວດ, ອະນຸມັດ/ອອກໃບ, ຜ່ານດ່ານ ແລະປິດແຟ້ມຕາມ workflow.','Track receipt, review, authorization/document issuance, border processing and closure.','TRACKING','SYSTEM','{}')
 ) AS t(service_code,step_code,sequence_no,name_lo,name_en,description_lo,description_en,step_type,actor_scope,configuration_json)
)
INSERT INTO system.service_step(service_version_id,step_code,sequence_no,name_lo,name_en,description_lo,description_en,step_type,actor_scope,configuration,status)
SELECT v.service_version_id,x.step_code,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,x.step_type,x.actor_scope,x.configuration_json::jsonb,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,step_code) DO UPDATE SET sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,step_type=EXCLUDED.step_type,actor_scope=EXCLUDED.actor_scope,configuration=EXCLUDED.configuration,status='ACTIVE';

WITH v AS (
 SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
 WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','COMPANY_MASTER','PRECONDITION',10,'ບໍລິສັດ ແລະ Site/Facility ຖືກສ້າງແລ້ວ','Company and relevant sites exist','ກວດຂໍ້ມູນ Legal Company ແລະ role-specific office/factory site ກ່ອນ.','Confirm legal company and role-specific office/factory sites first.',TRUE),
 ('VM-1003','PRODUCT_INFO','DATA',20,'ຂໍ້ມູນຜະລິດຕະພັນ','Product information','Trade/generic name, dosage form, target species, composition, use, shelf life, storage and related data.','Product identity, composition, use, shelf life, storage and related data.',TRUE),
 ('VM-1003','GMP_EVIDENCE','DOCUMENT',30,'ຫຼັກຖານ GMP/ຄຸນນະພາບສະຖານທີ່ຜະລິດ','GMP/manufacturing-quality evidence','ນຳໃຊ້ຕາມກໍລະນີ ແລະ configuration ທາງການ.','Use where applicable under official configuration.',TRUE),
 ('VM-1003','CPP_OR_ORIGIN_STATUS','DOCUMENT',40,'CPP/ຫຼັກຖານສະຖານະໃນປະເທດຕົ້ນກຳເນີດ','CPP/origin-country status evidence','ນຳໃຊ້ຕາມກໍລະນີ.','Use where applicable.',FALSE),
 ('VM-1003','LABEL_LEAFLET','DOCUMENT',50,'ສະຫຼາກ ແລະ ໃບແນະນຳ','Label and leaflet','ສະບັບທີ່ຈະສະເໜີຂໍອະນຸມັດ.','Proposed approval versions.',TRUE),
 ('VM-1003','QUALITY_SPEC','DOCUMENT',60,'Specification/Stability/Quality information','Specification/Stability/Quality information','ເອກະສານຄຸນນະພາບຕາມກໍລະນີ.','Quality information where applicable.',FALSE),

 ('TR-1021','COMPANY_SITE','PRECONDITION',10,'Company/Site ຜູ້ຍື່ນແຜນ','Submitting company/site','ເລືອກຈາກ Company Master.','Select from Company Master.',TRUE),
 ('TR-1021','PLAN_ITEMS','DATA',20,'ລາຍການແຜນ','Plan item list','ລາຍການ, ປະລິມານ, ຫົວໜ່ວຍ, ຂະໜາດບັນຈຸ/ທະບຽນທີ່ກ່ຽວຂ້ອງ.','Items, quantities, units and relevant package/registration references.',TRUE),

 ('TR-1007','COMPANY_SITE','PRECONDITION',10,'Company/Site ຜູ້ຍື່ນ','Submitting company/site','ເລືອກຈາກ Company Master.','Select from Company Master.',TRUE),
 ('TR-1007','ANNUAL_PLAN','PRECONDITION',20,'ແຜນປະຈຳປີທີ່ກ່ຽວຂ້ອງ','Relevant annual plan','ໃຊ້ຕາມ workflow/rule configuration ທີ່ປະກາດໃຊ້.','Use according to the published workflow/rule configuration.',FALSE),
 ('TR-1007','INVOICE','DOCUMENT',30,'Invoice','Invoice','ຂໍ້ມູນ Invoice ແລະໄຟລ໌ປະກອບຖ້າກຳນົດ.','Invoice data and supporting file when configured.',TRUE),
 ('TR-1007','ITEM_LIST','DATA',40,'ລາຍການນຳເຂົ້າ','Import item list','ຮອງຮັບຢາ/ວັກຊີນ/ຊີວະພັນ/ອຸປະກອນໃນຄຳຮ້ອງດຽວ.','Supports mixed medicines/vaccines/biologicals/devices in one application.',TRUE),
 ('TR-1007','OTHER_CONFIGURED_DOCS','DOCUMENT',50,'ເອກະສານອື່ນຕາມການກຳນົດ','Other configured supporting documents','ລາຍການນີ້ຕ້ອງອີງ service/rule configuration ທາງການ.','This list must follow official service/rule configuration.',FALSE)
 ) AS t(service_code,requirement_code,requirement_type,sequence_no,name_lo,name_en,description_lo,description_en,is_required)
)
INSERT INTO system.service_requirement(service_version_id,requirement_code,requirement_type,sequence_no,name_lo,name_en,description_lo,description_en,is_required,status)
SELECT v.service_version_id,x.requirement_code,x.requirement_type,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,x.is_required,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,requirement_code) DO UPDATE SET requirement_type=EXCLUDED.requirement_type,sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,is_required=EXCLUDED.is_required,status='ACTIVE';

WITH v AS (
 SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
 WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','REGISTRATION_RECORD','REGISTRATION',10,'ບັນທຶກ/ຜົນການຂຶ້ນທະບຽນ','Registration record/result','ຜົນອອກຕາມການຕັດສິນ ແລະ template ທາງການ.','Output according to regulatory decision and official template.'),
 ('VM-1003','REGISTRATION_CERTIFICATE','CERTIFICATE',20,'ໃບທະບຽນ','Registration certificate','1 presentation/ຂະໜາດບັນຈຸສາມາດອອກເປັນໃບແຍກຕາມ rule configuration.','Presentation-level certificates may be issued separately according to configured rules.'),
 ('TR-1021','PLAN_RECORD','APPROVAL_RECORD',10,'ແຜນປະຈຳປີທີ່ບັນທຶກ/ພິຈາລະນາແລ້ວ','Annual plan record','ໃຊ້ເປັນຖານອ້າງອີງສຳລັບຄຳຮ້ອງຄັ້ງຕໍ່ໄປຕາມ configuration.','Used as reference for later import applications according to configuration.'),
 ('TR-1007','IMPORT_NOTIFICATION','PERMIT',10,'ໃບແຈ້ງ/ໃບອະນຸຍາດນຳເຂົ້າ','Import notification/permit','ອອກຫຼັງຜ່ານ decision/authorization ຕາມ workflow.','Issued after configured decision/authorization workflow.')
 ) AS t(service_code,output_code,output_type,sequence_no,name_lo,name_en,description_lo,description_en)
)
INSERT INTO system.service_output(service_version_id,output_code,output_type,sequence_no,name_lo,name_en,description_lo,description_en,status)
SELECT v.service_version_id,x.output_code,x.output_type,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,output_code) DO UPDATE SET output_type=EXCLUDED.output_type,sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,status='ACTIVE';
