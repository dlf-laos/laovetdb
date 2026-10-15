-- LVSP v1.2.0 — Veterinary Drug Controlled Reference Data & Regulatory Automation
-- Reuses the proven admin(4) controlled vocabularies while making them database-configurable.
-- ATCvet labels are reference mappings; official codes must remain reviewable and updateable.

CREATE TABLE lookup.veterinary_drug_reference_term (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_code VARCHAR(40) NOT NULL,
  code VARCHAR(80) NOT NULL,
  parent_code VARCHAR(80),
  value_text TEXT NOT NULL,
  name_lo TEXT,
  name_en TEXT,
  sort_order INTEGER NOT NULL DEFAULT 100,
  source_system VARCHAR(80),
  source_reference TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(domain_code,code)
);
CREATE INDEX idx_vet_drug_reference_domain_active ON lookup.veterinary_drug_reference_term(domain_code,is_active,sort_order);
CREATE TRIGGER trg_vet_drug_reference_updated_at BEFORE UPDATE ON lookup.veterinary_drug_reference_term FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE product.veterinary_registration_number_sequence (
  prefix VARCHAR(10) NOT NULL,
  year_month CHAR(6) NOT NULL,
  last_no INTEGER NOT NULL DEFAULT 0 CHECK(last_no>=0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(prefix,year_month)
);

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS registration_number_source VARCHAR(20) NOT NULL DEFAULT 'LEGACY';

INSERT INTO lookup.veterinary_drug_reference_term(domain_code,code,parent_code,value_text,name_lo,name_en,sort_order,source_system,source_reference,metadata)
VALUES
('CATEGORY','VACCINE',NULL,'ວັກຊິນ (Vaccine)','ວັກຊິນ (Vaccine)','Vaccine',1,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIMICROBIAL',NULL,'ຢາຕ້ານເຊື້ອ (Antibiotic / Antimicrobial)','ຢາຕ້ານເຊື້ອ (Antibiotic / Antimicrobial)','Antibiotic / Antimicrobial',2,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIVIRAL',NULL,'ຢາຕ້ານໄວຣັດ (Antiviral)','ຢາຕ້ານໄວຣັດ (Antiviral)','Antiviral',3,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIFUNGAL',NULL,'ຢາຕ້ານເຊື້ອລາ (Antifungal)','ຢາຕ້ານເຊື້ອລາ (Antifungal)','Antifungal',4,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIPARASITIC',NULL,'ຢາຕ້ານກາຝາກ (Antiparasitic)','ຢາຕ້ານກາຝາກ (Antiparasitic)','Antiparasitic',5,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','VITAMIN_MINERAL_SUPPLEMENT',NULL,'ວິຕາມິນ, ແຮ່ທາດ ແລະ ສານເສີມອາຫານສັດ (Vitamin / Mineral / Supplement)','ວິຕາມິນ, ແຮ່ທາດ ແລະ ສານເສີມອາຫານສັດ (Vitamin / Mineral / Supplement)','Vitamin / Mineral / Supplement',6,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTI_INFLAMMATORY_ANALGESIC',NULL,'ຢາຕ້ານການອັກເສບ ແລະ ແກ້ປວດ (Anti-inflammatory / Analgesic)','ຢາຕ້ານການອັກເສບ ແລະ ແກ້ປວດ (Anti-inflammatory / Analgesic)','Anti-inflammatory / Analgesic',7,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','HORMONAL_REPRODUCTIVE',NULL,'ຢາຮໍໂມນ ແລະ ຢາຄວບຄຸມລະບົບສືບພັນ (Hormonal / Reproductive)','ຢາຮໍໂມນ ແລະ ຢາຄວບຄຸມລະບົບສືບພັນ (Hormonal / Reproductive)','Hormonal / Reproductive',8,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTISEPTIC_DISINFECTANT',NULL,'ຢາຂ້າເຊື້ອ (Antiseptic / Disinfectant)','ຢາຂ້າເຊື້ອ (Antiseptic / Disinfectant)','Antiseptic / Disinfectant',9,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANESTHETIC_SEDATIVE',NULL,'ຢາສະຫຼົບ ແລະ ຢາລະງັບປະສາດ (Anesthetic / Sedative)','ຢາສະຫຼົບ ແລະ ຢາລະງັບປະສາດ (Anesthetic / Sedative)','Anesthetic / Sedative',10,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','OTHER_SPECIFIC_THERAPY',NULL,'ຢາອື່ນໆ ຫຼື ຢາປິ່ນປົວສະເພາະທາງ (Other / Specific Therapy)','ຢາອື່ນໆ ຫຼື ຢາປິ່ນປົວສະເພາະທາງ (Other / Specific Therapy)','Other / Specific Therapy',11,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),

('DOSAGE_GROUP','inj',NULL,'inj','ຢາສັກ (Injectables)','Injectables',1,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),
('DOSAGE_GROUP','oral',NULL,'oral','ຢາທາງປາກ (Oral Forms)','Oral Forms',2,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),
('DOSAGE_GROUP','topical',NULL,'topical','ພາຍນອກ (Topical Forms)','Topical Forms',3,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),

('DOSAGE_FORM','LYOPHILIZED_INJECTION','inj','ຜົງແຫ້ງສຳລັບສັກ (Lyophilized powder for injection)','ຜົງແຫ້ງສຳລັບສັກ','Lyophilized powder for injection',1,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SOLUTION_INJECTION','inj','ຢານ້ຳສຳເລັດຮູບ (Solution for injection)','ຢານ້ຳສຳເລັດຮູບ','Solution for injection',2,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SUSPENSION_INJECTION','inj','ຢາທາດແຂວນລອຍ (Suspension for injection)','ຢາທາດແຂວນລອຍ','Suspension for injection',3,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_SOLUTION','oral','ຢານ້ຳກິນ (Oral solution)','ຢານ້ຳກິນ','Oral solution',10,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_POWDER','oral','ຜົງລະລາຍນ້ຳກິນ (Oral powder / Water Soluble Powder)','ຜົງລະລາຍນ້ຳກິນ','Oral powder / Water Soluble Powder',11,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','PREMIX','oral','ຢາປະສົມອາຫານສັດ (Premix)','ຢາປະສົມອາຫານສັດ','Premix',12,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','TABLET_BOLUS','oral','ຢາເມັດ / ຢາເມັດຂະໜາດໃຫຍ່ (Tablet / Bolus)','ຢາເມັດ / ໂບລັສ','Tablet / Bolus',13,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','CHEWABLE_TABLET','oral','ຢາເມັດແບບຫຍ້ຳ (Chewable Tablet)','ຢາເມັດແບບຫຍ້ຳ','Chewable Tablet',14,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','CAPSULE','oral','ແຄັບຊູນ (Capsule)','ແຄັບຊູນ','Capsule',15,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_PASTE','oral','ຢາປ້າຍ / ຢາເນື້ອຄຣີມ (Oral paste)','ຢາປ້າຍ / ຢາເນື້ອຄຣີມ','Oral paste',16,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','POUR_ON','topical','ຢາຢອດຫຼັງ / ລາດຫຼັງ (Pour-on solution)','ຢາຢອດຫຼັງ / ລາດຫຼັງ','Pour-on solution',20,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SPRAY','topical','ຢາພົ່ນ (Spray solution)','ຢາພົ່ນ','Spray solution',21,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','OINTMENT_CREAM','topical','ຢາຂີ້ເຜິ້ງ / ຄຣີມທາແຜ (Ointment / Cream)','ຢາຂີ້ເຜິ້ງ / ຄຣີມ','Ointment / Cream',22,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SPOT_ON','topical','ຢາຢອດສະເພາະຈຸດ (Spot-On)','ຢາຢອດສະເພາະຈຸດ','Spot-On',23,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','DIP_SHAMPOO','topical','ຢາອາບນ້ຳ / ຢາແຊ່ (Dip / Shampoo)','ຢາອາບນ້ຳ / ຢາແຊ່','Dip / Shampoo',24,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),

('DISTRIBUTION','POM',NULL,'POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ','POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ','Prescription Only Medicine',1,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('DISTRIBUTION','OTC',NULL,'OTC — ຈຳໜ່າຍທົ່ວໄປ','OTC — ຈຳໜ່າຍທົ່ວໄປ','Over the Counter',2,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('DISTRIBUTION','CONTROLLED',NULL,'ຄວບຄຸມພິເສດ (Controlled)','ຄວບຄຸມພິເສດ (Controlled)','Controlled',3,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),

('ROUTE','IM',NULL,'ສັກເຂົ້າກ້າມ (IM)','ສັກເຂົ້າກ້າມ','Intramuscular',1,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','SC',NULL,'ສັກໃຕ້ຜິວໜັງ (SC)','ສັກໃຕ້ຜິວໜັງ','Subcutaneous',2,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IV',NULL,'ສັກເຂົ້າເສັ້ເລືອດ (IV)','ສັກເຂົ້າເສັ້ເລືອດ','Intravenous',3,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IP',NULL,'ສັກເຂົ້າຊ່ອງທ້ອງ (IP)','ສັກເຂົ້າຊ່ອງທ້ອງ','Intraperitoneal',4,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','ORAL',NULL,'ກິນ (PO / Oral)','ກິນ','Oral',5,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','DRINKING_WATER',NULL,'ປະສົມນ້ຳດື່ມ','ປະສົມນ້ຳດື່ມ','In drinking water',6,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','FEED',NULL,'ປະສົມອາຫານສັດ','ປະສົມອາຫານສັດ','In feed',7,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','TOPICAL',NULL,'ທາຜິວໜັງ (Topical)','ທາຜິວໜັງ','Topical',8,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','POUR_ON',NULL,'ຢອດຫຼັງ (Pour-on)','ຢອດຫຼັງ','Pour-on',9,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','SPOT_ON',NULL,'ຢອດສະເພາະຈຸດ (Spot-on)','ຢອດສະເພາະຈຸດ','Spot-on',10,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','SPRAY',NULL,'ພົ່ນລະອອງ (Spray / Aerosol)','ພົ່ນລະອອງ','Spray / Aerosol',11,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','EYE_EAR',NULL,'ຢອດຕາ / ຢອດຫູ','ຢອດຕາ / ຢອດຫູ','Eye / Ear',12,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','INTRAMAMMARY',NULL,'ສອດເຕົ້ານົມ (Intramammary)','ສອດເຕົ້ານົມ','Intramammary',13,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IMMERSION',NULL,'ແຊ່ນ້ຳ (Immersion)','ແຊ່ນ້ຳ','Immersion',14,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','OCULAR',NULL,'ຢອດຕາ (Ocular)','ຢອດຕາ','Ocular',15,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','INTRANASAL',NULL,'ຢອດດັງ (Intranasal)','ຢອດດັງ','Intranasal',16,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),

('ATCVET','QA',NULL,'QA — ລະບົບຍ່ອຍອາຫານ & ເມຕາໂບລິຊຶມ','QA — ລະບົບຍ່ອຍອາຫານ & ເມຕາໂບລິຊຶມ','Alimentary tract and metabolism',1,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QB',NULL,'QB — ເລືອດ & ອະໄວຍະວະສ້າງເລືອດ','QB — ເລືອດ & ອະໄວຍະວະສ້າງເລືອດ','Blood and blood forming organs',2,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QC',NULL,'QC — ຫົວໃຈ & ຫຼອດເລືອດ','QC — ຫົວໃຈ & ຫຼອດເລືອດ','Cardiovascular system',3,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QD',NULL,'QD — ຜິວໜັງ','QD — ຜິວໜັງ','Dermatologicals',4,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIFUNGAL","ANTISEPTIC_DISINFECTANT"]}'),
('ATCVET','QG',NULL,'QG — ສືບພັນ & ຮໍໂມນເພດ','QG — ສືບພັນ & ຮໍໂມນເພດ','Genito urinary system and sex hormones',5,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["HORMONAL_REPRODUCTIVE"]}'),
('ATCVET','QH',NULL,'QH — ຮໍໂມນລະບົບ','QH — ຮໍໂມນລະບົບ','Systemic hormonal preparations',6,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["HORMONAL_REPRODUCTIVE"]}'),
('ATCVET','QI',NULL,'QI — ວັກຊີນ/ຜະລິດຕະພັນພູມຄຸ້ມກັນ','QI — ວັກຊີນ/ຜະລິດຕະພັນພູມຄຸ້ມກັນ','Immunologicals',7,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["VACCINE"]}'),
('ATCVET','QJ',NULL,'QJ — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','QJ — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','Antiinfectives for systemic use',8,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL","ANTIVIRAL","ANTIFUNGAL"]}'),
('ATCVET','QJ01','QJ','QJ01 — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ (Antibacterials)','QJ01 — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','Antibacterials for systemic use',9,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL"]}'),
('ATCVET','QJ05','QJ','QJ05 — ຢາຕ້ານໄວຣັດ (Antivirals)','QJ05 — ຢາຕ້ານໄວຣັດ','Antivirals for systemic use',10,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIVIRAL"]}'),
('ATCVET','QJ51','QJ','QJ51 — ຢາຕ້ານເຊື້ອສອດເຕົ້ານົມ (Intramammary)','QJ51 — ຢາຕ້ານເຊື້ອສອດເຕົ້ານົມ','Antibacterials for intramammary use',11,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL"]}'),
('ATCVET','QL',NULL,'QL — ຢາຕ້ານເນື້ອງອກ/ປັບພູມ','QL — ຢາຕ້ານເນື້ອງອກ/ປັບພູມ','Antineoplastic and immunomodulating agents',12,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QM',NULL,'QM — ກ້າມ & ກະດູກ','QM — ກ້າມ & ກະດູກ','Musculo-skeletal system',13,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTI_INFLAMMATORY_ANALGESIC"]}'),
('ATCVET','QM01','QM','QM01 — ຢາຕ້ານການອັກເສບ (NSAIDs)','QM01 — ຢາຕ້ານການອັກເສບ','Anti-inflammatory and antirheumatic products',14,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTI_INFLAMMATORY_ANALGESIC"]}'),
('ATCVET','QN',NULL,'QN — ລະບົບປະສາດ','QN — ລະບົບປະສາດ','Nervous system',15,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QN01','QN','QN01 — ຢາສະຫຼົບ / ຢາຊາ (Anaesthetics)','QN01 — ຢາສະຫຼົບ / ຢາຊາ','Anaesthetics',16,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QN05','QN','QN05 — ຢາລະງັບປະສາດ (Sedatives)','QN05 — ຢາລະງັບປະສາດ','Sedatives',17,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QP',NULL,'QP — ຢາຕ້ານກາຝາກ, ຂ້າແມງໄມ້','QP — ຢາຕ້ານກາຝາກ, ຂ້າແມງໄມ້','Antiparasitic products, insecticides and repellents',18,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP51','QP','QP51 — ຢາຕ້ານໂປຣໂຕຊົວ (Antiprotozoals)','QP51 — ຢາຕ້ານໂປຣໂຕຊົວ','Antiprotozoals',19,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP52','QP','QP52 — ຢາຖ່າຍພະຍາດ (Anthelmintics)','QP52 — ຢາຖ່າຍພະຍາດ','Anthelmintics',20,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP53','QP','QP53 — ຢາກຳຈັດກາຝາກຕົວນອກ ເຊັ່ນ ເຫັບ/ໝັດ (Ectoparasiticides)','QP53 — ຢາກຳຈັດກາຝາກຕົວນອກ','Ectoparasiticides',21,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP54','QP','QP54 — ຢາກຳຈັດກາຝາກພາຍໃນ+ພາຍນອກ (Endectocides)','QP54 — ຢາກຳຈັດກາຝາກພາຍໃນ+ພາຍນອກ','Endectocides',22,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QR',NULL,'QR — ລະບົບຫາຍໃຈ','QR — ລະບົບຫາຍໃຈ','Respiratory system',23,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QS',NULL,'QS — ຕາ/ຫູ','QS — ຕາ/ຫູ','Sensory organs',24,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QV',NULL,'QV — ອື່ນໆ (Various)','QV — ອື່ນໆ','Various',25,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["OTHER_SPECIFIC_THERAPY"]}')
ON CONFLICT(domain_code,code) DO UPDATE SET
  parent_code=excluded.parent_code,value_text=excluded.value_text,name_lo=excluded.name_lo,name_en=excluded.name_en,
  sort_order=excluded.sort_order,source_system=excluded.source_system,source_reference=excluded.source_reference,metadata=excluded.metadata,is_active=TRUE;

COMMENT ON TABLE lookup.veterinary_drug_reference_term IS 'Configurable controlled values for veterinary drug regulatory forms. Seeds preserve proven legacy behavior and may be updated through governance without changing product records.';
COMMENT ON COLUMN product.product_regulatory_profile.registration_number_source IS 'AUTO, MANUAL, or LEGACY/EXISTING. Manual values remain audited and uniqueness constrained by registration_no.';
