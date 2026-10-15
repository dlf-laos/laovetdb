
-- ============================================================================
-- SEED: 001_admin_unit_types.sql
-- ============================================================================
INSERT INTO lookup.admin_unit_type(code,level_no,name_lo,name_en,is_active) VALUES
('COUNTRY',0,'ປະເທດ','Country',TRUE),('PROVINCE',1,'ແຂວງ/ນະຄອນຫຼວງ','Province/Capital',TRUE),
('DISTRICT',2,'ເມືອງ','District',TRUE),('COMMUNE',3,'ຕາແສງ','Commune',TRUE),('VILLAGE',4,'ບ້ານ','Village',TRUE)
ON CONFLICT(code) DO UPDATE SET level_no=EXCLUDED.level_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 002_party_roles.sql
-- ============================================================================
INSERT INTO master.party_role_type(code,name_lo,name_en,allowed_party_kind,is_active) VALUES
('MANUFACTURER','ຜູ້ຜະລິດ','Manufacturer','COMPANY',TRUE),('IMPORTER','ຜູ້ນຳເຂົ້າ','Importer','COMPANY',TRUE),
('EXPORTER','ຜູ້ສົ່ງອອກ','Exporter','COMPANY',TRUE),('TRANSIT_OPERATOR','ຜູ້ດຳເນີນການສົ່ງຜ່ານ','Transit Operator','COMPANY',TRUE),
('DISTRIBUTOR','ຜູ້ຈຳໜ່າຍ','Distributor','COMPANY',TRUE),('FARM_OPERATOR','ຜູ້ດຳເນີນການຟາມ','Farm Operator',NULL,TRUE),
('FACILITY_OWNER','ເຈົ້າຂອງສະຖານທີ່','Facility Owner',NULL,TRUE),
('AUTHORIZED_REPRESENTATIVE','ຜູ້ຕາງໜ້າທີ່ໄດ້ຮັບອະນຸຍາດ','Authorized Representative',NULL,TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,allowed_party_kind=EXCLUDED.allowed_party_kind,is_active=TRUE;

-- ============================================================================
-- SEED: 003_facility_types.sql
-- ============================================================================
INSERT INTO lookup.facility_type(code,name_lo,name_en,is_active) VALUES
('VETERINARY_MEDICINE_FACTORY','ໂຮງງານຜະລິດຢາສັດ','Veterinary Medicine Factory',TRUE),
('VACCINE_FACTORY','ໂຮງງານວັກຊີນ/ຊີວະພັນ','Vaccine/Biological Factory',TRUE),('FEED_FACTORY','ໂຮງງານອາຫານສັດ','Feed Factory',TRUE),
('WAREHOUSE','ສາງ','Warehouse',TRUE),('VETERINARY_DRUG_STORE','ຮ້ານຂາຍຢາສັດ','Veterinary Drug Store',TRUE),
('VETERINARY_CLINIC','ຄລີນິກສັດຕະວະແພດ','Veterinary Clinic',TRUE),('VETERINARY_HOSPITAL','ໂຮງໝໍສັດ','Veterinary Hospital',TRUE),
('LABORATORY','ຫ້ອງວິໄຈ/ຫ້ອງແລັບ','Laboratory',TRUE),('FARM','ຟາມ','Farm',TRUE),('AQUACULTURE_FARM','ຟາມສັດນ້ຳ','Aquaculture Farm',TRUE),
('HATCHERY','ສູນເພາະພັນ','Hatchery',TRUE),('SLAUGHTERHOUSE','ໂຮງຂ້າສັດ','Slaughterhouse',TRUE),
('QUARANTINE_FACILITY','ສະຖານທີ່ກັກກັນ','Quarantine Facility',TRUE),('BREEDING_CENTER','ສູນປັບປຸງພັນ','Breeding Center',TRUE),
('AI_CENTER','ສູນປະສົມທຽມ','Artificial Insemination Center',TRUE),('BORDER_CHECKPOINT','ດ່ານກວດກາ','Border Checkpoint',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 004_product_types.sql
-- ============================================================================
INSERT INTO product.product_type(code,name_lo,name_en,is_active) VALUES
('VETERINARY_PHARMACEUTICAL','ຢາສັດ','Veterinary Pharmaceutical',TRUE),('VACCINE','ວັກຊີນ','Vaccine',TRUE),
('BIOLOGICAL','ຊີວະພັນ','Biological Product',TRUE),('DIAGNOSTIC_KIT','ຊຸດກວດວິນິດໄສ','Diagnostic Kit',TRUE),
('DISINFECTANT','ຢາຂ້າເຊື້ອ','Disinfectant',TRUE),('FEED','ອາຫານສັດ','Animal Feed',TRUE),('AQUAFEED','ອາຫານສັດນ້ຳ','Aquafeed',TRUE),
('FEED_ADDITIVE','ສານເສີມອາຫານສັດ','Feed Additive',TRUE),('PREMIX','ພຣີມິກ','Premix',TRUE),
('OTHER_REGULATED_PRODUCT','ຜະລິດຕະພັນຄວບຄຸມອື່ນ','Other Regulated Product',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 005_registration_license_types.sql
-- ============================================================================
INSERT INTO registration.registration_type(code,name_lo,name_en,is_active) VALUES
('VETERINARY_PRODUCT','ຂຶ້ນທະບຽນຜະລິດຕະພັນສັດຕະວະແພດ','Veterinary Product Registration',TRUE),
('FEED_PRODUCT','ຂຶ້ນທະບຽນອາຫານສັດ','Feed Product Registration',TRUE),('FACILITY','ຂຶ້ນທະບຽນສະຖານທີ່','Facility Registration',TRUE),
('MANUFACTURER','ຂຶ້ນທະບຽນຜູ້ຜະລິດ','Manufacturer Registration',TRUE),('TRADE_OPERATOR','ຂຶ້ນທະບຽນຜູ້ປະກອບການການຄ້າ','Trade Operator Registration',TRUE),
('PROFESSIONAL','ຂຶ້ນທະບຽນວິຊາຊີບ','Professional Registration',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;
INSERT INTO licensing.license_type(code,name_lo,name_en,is_active) VALUES
('FACILITY_OPERATING','ໃບອະນຸຍາດດຳເນີນງານສະຖານທີ່','Facility Operating Licence',TRUE),
('FACTORY_OPERATING','ໃບອະນຸຍາດດຳເນີນໂຮງງານ','Factory Operating Licence',TRUE),
('VETERINARY_DRUG_BUSINESS','ໃບອະນຸຍາດທຸລະກິດຢາສັດ','Veterinary Drug Business Licence',TRUE),
('FEED_BUSINESS','ໃບອະນຸຍາດທຸລະກິດອາຫານສັດ','Feed Business Licence',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 006_permissions_roles.sql
-- ============================================================================
INSERT INTO security.permission(code,description) VALUES
('master.person.read','master.person.read'),
('master.person.create','master.person.create'),
('master.person.update','master.person.update'),
('master.person.merge','master.person.merge'),
('master.company.read','master.company.read'),
('master.company.create','master.company.create'),
('master.company.update','master.company.update'),
('master.company.merge','master.company.merge'),
('master.facility.read','master.facility.read'),
('master.facility.create','master.facility.create'),
('master.facility.update','master.facility.update'),
('master.reference.read','master.reference.read'),
('master.reference.manage','master.reference.manage'),
('master.reference.approve','master.reference.approve'),
('security.user.read','security.user.read'),
('security.user.manage','security.user.manage'),
('security.role.read','security.role.read'),
('security.role.manage','security.role.manage'),
('security.delegation.create','security.delegation.create'),
('security.delegation.revoke','security.delegation.revoke'),
('workflow.definition.read','workflow.definition.read'),
('workflow.definition.manage','workflow.definition.manage'),
('workflow.definition.publish','workflow.definition.publish'),
('workflow.task.read','workflow.task.read'),
('workflow.task.claim','workflow.task.claim'),
('workflow.task.assign','workflow.task.assign'),
('workflow.task.complete','workflow.task.complete'),
('document.read','document.read'),
('document.upload','document.upload'),
('document.classify','document.classify'),
('document.generate','document.generate'),
('audit.read','audit.read'),
('audit.export','audit.export'),
('case.application.create','case.application.create'),
('case.application.submit','case.application.submit'),
('case.application.withdraw','case.application.withdraw'),
('case.application.read','case.application.read'),
('case.review.read','case.review.read'),
('case.review.review','case.review.review'),
('case.review.request_information','case.review.request_information'),
('case.review.complete','case.review.complete'),
('case.decision.create','case.decision.create'),
('case.decision.approve','case.decision.approve'),
('case.decision.reject','case.decision.reject'),
('case.decision.amend','case.decision.amend'),
('registration.read','registration.read'),
('registration.issue','registration.issue'),
('registration.renew','registration.renew'),
('registration.vary','registration.vary'),
('registration.suspend','registration.suspend'),
('registration.revoke','registration.revoke'),
('licensing.license.read','licensing.license.read'),
('licensing.license.issue','licensing.license.issue'),
('licensing.license.renew','licensing.license.renew'),
('licensing.license.amend','licensing.license.amend'),
('licensing.license.suspend','licensing.license.suspend'),
('licensing.license.restore','licensing.license.restore'),
('licensing.license.revoke','licensing.license.revoke'),
('certificate.read','certificate.read'),
('certificate.issue','certificate.issue'),
('certificate.revoke','certificate.revoke'),
('certificate.verify','certificate.verify'),
('facility.establishment.review','facility.establishment.review'),
('facility.establishment.approve','facility.establishment.approve'),
('facility.gmp.assess','facility.gmp.assess'),
('facility.gmp.approve','facility.gmp.approve'),
('product.registration.read','product.registration.read'),
('product.registration.review','product.registration.review'),
('product.registration.approve','product.registration.approve'),
('product.variation.review','product.variation.review'),
('product.variation.approve','product.variation.approve'),
('feed.registration.read','feed.registration.read'),
('feed.registration.review','feed.registration.review'),
('feed.registration.approve','feed.registration.approve'),
('inspection.case.create','inspection.case.create'),
('inspection.case.assign','inspection.case.assign'),
('inspection.case.perform','inspection.case.perform'),
('inspection.case.close','inspection.case.close'),
('inspection.finding.record','inspection.finding.record'),
('compliance.capa.review','compliance.capa.review'),
('compliance.capa.verify','compliance.capa.verify'),
('enforcement.case.read','enforcement.case.read'),
('enforcement.case.act','enforcement.case.act'),
('enforcement.case.decide','enforcement.case.decide'),
('enforcement.case.appeal_review','enforcement.case.appeal_review'),
('laboratory.sample.receive','laboratory.sample.receive'),
('laboratory.result.enter','laboratory.result.enter'),
('laboratory.result.validate','laboratory.result.validate'),
('laboratory.result.approve','laboratory.result.approve'),
('laboratory.result.amend','laboratory.result.amend'),
('animal.register','animal.register'),
('animal.identify','animal.identify'),
('animal.transfer','animal.transfer'),
('movement.review','movement.review'),
('movement.authorize','movement.authorize'),
('movement.complete','movement.complete'),
('disease.case.create','disease.case.create'),
('disease.case.investigate','disease.case.investigate'),
('disease.case.confirm','disease.case.confirm'),
('outbreak.declare','outbreak.declare'),
('outbreak.close','outbreak.close'),
('vaccination.record','vaccination.record'),
('trade.permit.review','trade.permit.review'),
('trade.permit.approve','trade.permit.approve'),
('trade.shipment.inspect','trade.shipment.inspect'),
('trade.shipment.quarantine','trade.shipment.quarantine'),
('trade.shipment.clear','trade.shipment.clear'),
('trade.certificate.issue','trade.certificate.issue'),
('fisheries.aquaculture.manage','fisheries.aquaculture.manage')
ON CONFLICT(code) DO NOTHING;

INSERT INTO security.role(code,name_lo,name_en,is_system_role,is_active) VALUES
('SYSTEM_ADMIN','SYSTEM ADMIN','System Admin',TRUE,TRUE),
('SECURITY_ADMIN','SECURITY ADMIN','Security Admin',TRUE,TRUE),
('DATA_STEWARD','DATA STEWARD','Data Steward',FALSE,TRUE),
('MASTER_DATA_APPROVER','MASTER DATA APPROVER','Master Data Approver',FALSE,TRUE),
('REGISTRY_OFFICER','REGISTRY OFFICER','Registry Officer',FALSE,TRUE),
('TECHNICAL_REVIEWER','TECHNICAL REVIEWER','Technical Reviewer',FALSE,TRUE),
('INSPECTOR','INSPECTOR','Inspector',FALSE,TRUE),
('SENIOR_INSPECTOR','SENIOR INSPECTOR','Senior Inspector',FALSE,TRUE),
('LAB_ANALYST','LAB ANALYST','Lab Analyst',FALSE,TRUE),
('LAB_VALIDATOR','LAB VALIDATOR','Lab Validator',FALSE,TRUE),
('LAB_APPROVER','LAB APPROVER','Lab Approver',FALSE,TRUE),
('EPIDEMIOLOGIST','EPIDEMIOLOGIST','Epidemiologist',FALSE,TRUE),
('QUARANTINE_OFFICER','QUARANTINE OFFICER','Quarantine Officer',FALSE,TRUE),
('BORDER_OFFICER','BORDER OFFICER','Border Officer',FALSE,TRUE),
('LICENSING_OFFICER','LICENSING OFFICER','Licensing Officer',FALSE,TRUE),
('APPROVING_AUTHORITY','APPROVING AUTHORITY','Approving Authority',FALSE,TRUE),
('CERTIFICATE_SIGNATORY','CERTIFICATE SIGNATORY','Certificate Signatory',FALSE,TRUE),
('AUDITOR','AUDITOR','Auditor',FALSE,TRUE),
('MANAGEMENT_VIEWER','MANAGEMENT VIEWER','Management Viewer',FALSE,TRUE),
('COMPANY_ADMIN','COMPANY ADMIN','Company Admin',FALSE,TRUE),
('COMPANY_USER','COMPANY USER','Company User',FALSE,TRUE),
('FARM_OPERATOR','FARM OPERATOR','Farm Operator',FALSE,TRUE),
('PUBLIC_USER','PUBLIC USER','Public User',FALSE,TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 007_workflow_families.sql
-- ============================================================================
INSERT INTO workflow.definition(workflow_code,name_lo,name_en,is_active) VALUES
('WF-001','ການຂຶ້ນທະບຽນທົ່ວໄປ','Generic Registration',TRUE),('WF-002','ການອະນຸຍາດທົ່ວໄປ','Generic Licensing',TRUE),
('WF-003','ຂຶ້ນທະບຽນຜະລິດຕະພັນ','Product Registration',TRUE),('WF-004','ສ້າງຕັ້ງໂຮງງານ/ສະຖານທີ່','Factory Establishment',TRUE),
('WF-005','ການປະເມີນ GMP/ເຕັກນິກ','GMP / Technical Certification',TRUE),('WF-006','ນຳເຂົ້າ/ສົ່ງອອກ/ສົ່ງຜ່ານ','Import / Export / Transit',TRUE),
('WF-007','ກວດກາ ແລະ CAPA','Inspection & CAPA',TRUE),('WF-008','ການທົດສອບຫ້ອງວິໄຈ','Laboratory Testing',TRUE),
('WF-009','ສືບສວນພະຍາດ/ການລະບາດ','Disease Investigation & Outbreak',TRUE),('WF-010','ການເຄື່ອນຍ້າຍສັດ','Animal Movement',TRUE),
('WF-011','ການບັງຄັບລະບຽບ','Regulatory Enforcement',TRUE),('WF-012','ປ່ຽນແປງຂໍ້ມູນຫຼັກ','Master Data Change',TRUE)
ON CONFLICT(workflow_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 008_trade_permit_types.sql
-- ============================================================================
INSERT INTO trade.permit_type(code,name_lo,name_en,is_active) VALUES
('LIVE_ANIMAL_IMPORT','ອະນຸຍາດນຳເຂົ້າສັດມີຊີວິດ','Live Animal Import Permit',TRUE),
('ANIMAL_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດ','Animal Product Import Permit',TRUE),
('AQUATIC_ANIMAL_IMPORT','ອະນຸຍາດນຳເຂົ້າສັດນ້ຳ','Aquatic Animal Import Permit',TRUE),
('AQUATIC_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດນ້ຳ','Aquatic Product Import Permit',TRUE),
('VETERINARY_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດຕະວະແພດ','Veterinary Product Import Permit',TRUE),
('FEED_IMPORT','ອະນຸຍາດນຳເຂົ້າອາຫານສັດ','Feed Import Permit',TRUE),('EXPORT','ອະນຸຍາດສົ່ງອອກ','Export Authorization',TRUE),
('TRANSIT','ອະນຸຍາດສົ່ງຜ່ານ','Transit Authorization',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

-- ============================================================================
-- SEED: 009_service_baseline.sql
-- ============================================================================
INSERT INTO system.service_definition(service_code,domain_code,name_lo,name_en,description,is_public,is_active) VALUES
('VM-1003','VM','ຂຶ້ນທະບຽນຜະລິດຕະພັນສັດຕະວະແພດ','Veterinary Product Registration','Regulatory product registration service',TRUE,TRUE),
('VF-1002','VF','ຄຳຂໍສ້າງຕັ້ງສະຖານທີ່','Facility Establishment Application','Regulated facility establishment service',TRUE,TRUE),
('IN-1007','IN','ການກວດກາປົກກະຕິ','Routine Inspection','Enterprise inspection service',FALSE,TRUE),
('LAB-1002','LAB','ລົງທະບຽນຕົວຢ່າງ','Sample Registration','Laboratory sample registration service',FALSE,TRUE),
('AH-1001','AH','ຕິດຕາມພະຍາດສັດ','Animal Disease Surveillance','Animal health surveillance service',FALSE,TRUE),
('TR-1001','TR','ຂຶ້ນທະບຽນຜູ້ປະກອບການການຄ້າ','Trade Operator Registration','Trade operator registration service',TRUE,TRUE),
('FI-1002','FI','ຂຶ້ນທະບຽນຟາມສັດນ້ຳ','Aquaculture Facility Registration','Aquaculture facility registration service',TRUE,TRUE),
('AF-1006','AF','ຂຶ້ນທະບຽນອາຫານສັດ','Animal Feed Product Registration','Feed product registration service',TRUE,TRUE)
ON CONFLICT(service_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description=EXCLUDED.description,is_public=EXCLUDED.is_public,is_active=TRUE;

-- ============================================================================
-- SEED: 010_role_permission_baseline.sql
-- ============================================================================
-- Conservative starter mapping. Review against official delegation/organization rules before production.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'security.%'
WHERE r.code='SECURITY_ADMIN' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'master.%'
WHERE r.code='DATA_STEWARD' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('master.reference.read','master.reference.approve')
WHERE r.code='MASTER_DATA_APPROVER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'inspection.%'
WHERE r.code IN ('INSPECTOR','SENIOR_INSPECTOR') ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON
 (r.code='LAB_ANALYST' AND p.code IN ('laboratory.sample.receive','laboratory.result.enter')) OR
 (r.code='LAB_VALIDATOR' AND p.code='laboratory.result.validate') OR
 (r.code='LAB_APPROVER' AND p.code='laboratory.result.approve')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'disease.%' OR p.code LIKE 'outbreak.%' OR p.code='vaccination.record'
WHERE r.code='EPIDEMIOLOGIST' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('audit.read','audit.export')
WHERE r.code='AUDITOR' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code='certificate.verify'
WHERE r.code='PUBLIC_USER' ON CONFLICT DO NOTHING;

-- ============================================================================
-- SEED: 011_workflow_version_baseline.sql
-- ============================================================================
-- Create version 1 as DRAFT for every workflow family. Domain/legal review must publish a workflow before use.
INSERT INTO workflow.definition_version(definition_id,version_no,effective_from,status)
SELECT id,1,now(),'DRAFT' FROM workflow.definition
ON CONFLICT(definition_id,version_no) DO NOTHING;

-- Seed the generic regulatory pattern for WF-001 only. Other workflow families remain DRAFT for domain-specific configuration.
WITH v AS (
 SELECT dv.id FROM workflow.definition_version dv JOIN workflow.definition d ON d.id=dv.definition_id
 WHERE d.workflow_code='WF-001' AND dv.version_no=1
)
INSERT INTO workflow.step(workflow_version_id,step_code,name_lo,name_en,step_type,sequence_no)
SELECT v.id,x.code,x.lo,x.en,'HUMAN_TASK',x.seq FROM v CROSS JOIN (VALUES
 ('DRAFT','ຮ່າງ','Draft',10),('SUBMITTED','ຍື່ນແລ້ວ','Submitted',20),('RECEIVED','ຮັບແລ້ວ','Received',30),
 ('ADMISSIBILITY_CHECK','ກວດຄວາມຄົບຖ້ວນ','Admissibility Check',40),('TECHNICAL_REVIEW','ກວດດ້ານວິຊາການ','Technical Review',50),
 ('READY_FOR_DECISION','ພ້ອມພິຈາລະນາ','Ready for Decision',60),('DECISION','ການຕັດສິນ','Decision',70),
 ('DOCUMENT_ISSUANCE','ອອກເອກະສານ','Document Issuance',80),('COMPLETED','ສຳເລັດ','Completed',90)
) AS x(code,lo,en,seq)
ON CONFLICT(workflow_version_id,step_code) DO NOTHING;

-- ============================================================================
-- SEED: 012_service_version_baseline.sql
-- ============================================================================
-- Initial service versions are DRAFT until legal/workflow configuration is reviewed and published.
INSERT INTO system.service_version(service_id,version_no,effective_from,workflow_code,status)
SELECT id,1,now(),
 CASE domain_code
  WHEN 'VM' THEN 'WF-003' WHEN 'VF' THEN 'WF-004' WHEN 'IN' THEN 'WF-007' WHEN 'LAB' THEN 'WF-008'
  WHEN 'AH' THEN 'WF-009' WHEN 'TR' THEN 'WF-006' WHEN 'FI' THEN 'WF-002' WHEN 'AF' THEN 'WF-003'
  ELSE 'WF-001' END,
 'DRAFT'
FROM system.service_definition
ON CONFLICT(service_id,version_no) DO NOTHING;
