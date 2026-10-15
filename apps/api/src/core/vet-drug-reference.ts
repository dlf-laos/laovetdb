// Veterinary-drug controlled vocabulary fallback used outside PostgreSQL mode.
// PostgreSQL lookup.veterinary_drug_reference_term is authoritative in Neon.
// Values preserve the proven legacy admin(4) labels while exposing stable codes.
// @ts-nocheck

export const vetDrugReferenceFallback={
  categories:[
    ['VACCINE','ວັກຊິນ (Vaccine)','Vaccine'],
    ['ANTIMICROBIAL','ຢາຕ້ານເຊື້ອ (Antibiotic / Antimicrobial)','Antibiotic / Antimicrobial'],
    ['ANTIVIRAL','ຢາຕ້ານໄວຣັດ (Antiviral)','Antiviral'],
    ['ANTIFUNGAL','ຢາຕ້ານເຊື້ອລາ (Antifungal)','Antifungal'],
    ['ANTIPARASITIC','ຢາຕ້ານກາຝາກ (Antiparasitic)','Antiparasitic'],
    ['VITAMIN_MINERAL_SUPPLEMENT','ວິຕາມິນ, ແຮ່ທາດ ແລະ ສານເສີມອາຫານສັດ (Vitamin / Mineral / Supplement)','Vitamin / Mineral / Supplement'],
    ['ANTI_INFLAMMATORY_ANALGESIC','ຢາຕ້ານການອັກເສບ ແລະ ແກ້ປວດ (Anti-inflammatory / Analgesic)','Anti-inflammatory / Analgesic'],
    ['HORMONAL_REPRODUCTIVE','ຢາຮໍໂມນ ແລະ ຢາຄວບຄຸມລະບົບສືບພັນ (Hormonal / Reproductive)','Hormonal / Reproductive'],
    ['ANTISEPTIC_DISINFECTANT','ຢາຂ້າເຊື້ອ (Antiseptic / Disinfectant)','Antiseptic / Disinfectant'],
    ['ANESTHETIC_SEDATIVE','ຢາສະຫຼົບ ແລະ ຢາລະງັບປະສາດ (Anesthetic / Sedative)','Anesthetic / Sedative'],
    ['OTHER_SPECIFIC_THERAPY','ຢາອື່ນໆ ຫຼື ຢາປິ່ນປົວສະເພາະທາງ (Other / Specific Therapy)','Other / Specific Therapy']
  ].map(([code,valueText,nameEn],i)=>({code,valueText,nameLo:valueText,nameEn,sortOrder:i+1})),
  dosageGroups:[
    {code:'inj',valueText:'inj',nameLo:'ຢາສັກ (Injectables)',nameEn:'Injectables',sortOrder:1},
    {code:'oral',valueText:'oral',nameLo:'ຢາທາງປາກ (Oral Forms)',nameEn:'Oral Forms',sortOrder:2},
    {code:'topical',valueText:'topical',nameLo:'ພາຍນອກ (Topical Forms)',nameEn:'Topical Forms',sortOrder:3}
  ],
  dosageForms:[
    ['LYOPHILIZED_INJECTION','inj','ຜົງແຫ້ງສຳລັບສັກ (Lyophilized powder for injection)','Lyophilized powder for injection'],
    ['SOLUTION_INJECTION','inj','ຢານ້ຳສຳເລັດຮູບ (Solution for injection)','Solution for injection'],
    ['SUSPENSION_INJECTION','inj','ຢາທາດແຂວນລອຍ (Suspension for injection)','Suspension for injection'],
    ['ORAL_SOLUTION','oral','ຢານ້ຳກິນ (Oral solution)','Oral solution'],
    ['ORAL_POWDER','oral','ຜົງລະລາຍນ້ຳກິນ (Oral powder / Water Soluble Powder)','Oral powder / Water Soluble Powder'],
    ['PREMIX','oral','ຢາປະສົມອາຫານສັດ (Premix)','Premix'],
    ['TABLET_BOLUS','oral','ຢາເມັດ / ຢາເມັດຂະໜາດໃຫຍ່ (Tablet / Bolus)','Tablet / Bolus'],
    ['CHEWABLE_TABLET','oral','ຢາເມັດແບບຫຍ້ຳ (Chewable Tablet)','Chewable Tablet'],
    ['CAPSULE','oral','ແຄັບຊູນ (Capsule)','Capsule'],
    ['ORAL_PASTE','oral','ຢາປ້າຍ / ຢາເນື້ອຄຣີມ (Oral paste)','Oral paste'],
    ['POUR_ON','topical','ຢາຢອດຫຼັງ / ລາດຫຼັງ (Pour-on solution)','Pour-on solution'],
    ['SPRAY','topical','ຢາພົ່ນ (Spray solution)','Spray solution'],
    ['OINTMENT_CREAM','topical','ຢາຂີ້ເຜິ້ງ / ຄຣີມທາແຜ (Ointment / Cream)','Ointment / Cream'],
    ['SPOT_ON','topical','ຢາຢອດສະເພາະຈຸດ (Spot-On)','Spot-On'],
    ['DIP_SHAMPOO','topical','ຢາອາບນ້ຳ / ຢາແຊ່ (Dip / Shampoo)','Dip / Shampoo']
  ].map(([code,parentCode,valueText,nameEn],i)=>({code,parentCode,valueText,nameLo:valueText,nameEn,sortOrder:i+1})),
  distributions:[
    {code:'POM',valueText:'POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ',nameLo:'POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ',nameEn:'Prescription Only Medicine',sortOrder:1},
    {code:'OTC',valueText:'OTC — ຈຳໜ່າຍທົ່ວໄປ',nameLo:'OTC — ຈຳໜ່າຍທົ່ວໄປ',nameEn:'Over the Counter',sortOrder:2},
    {code:'CONTROLLED',valueText:'ຄວບຄຸມພິເສດ (Controlled)',nameLo:'ຄວບຄຸມພິເສດ (Controlled)',nameEn:'Controlled',sortOrder:3}
  ],
  routes:[
    ['IM','ສັກເຂົ້າກ້າມ (IM)','Intramuscular'],['SC','ສັກໃຕ້ຜິວໜັງ (SC)','Subcutaneous'],['IV','ສັກເຂົ້າເສັ້ນເລືອດ (IV)','Intravenous'],['IP','ສັກເຂົ້າຊ່ອງທ້ອງ (IP)','Intraperitoneal'],
    ['ORAL','ກິນ (PO / Oral)','Oral'],['DRINKING_WATER','ປະສົມນ້ຳດື່ມ','In drinking water'],['FEED','ປະສົມອາຫານສັດ','In feed'],['TOPICAL','ທາຜິວໜັງ (Topical)','Topical'],['POUR_ON','ຢອດຫຼັງ (Pour-on)','Pour-on'],['SPOT_ON','ຢອດສະເພາະຈຸດ (Spot-on)','Spot-on'],['SPRAY','ພົ່ນລະອອງ (Spray / Aerosol)','Spray / Aerosol'],['EYE_EAR','ຢອດຕາ / ຢອດຫູ','Eye / Ear'],['INTRAMAMMARY','ສອດເຕົ້ານົມ (Intramammary)','Intramammary'],['IMMERSION','ແຊ່ນ້ຳ (Immersion)','Immersion'],['OCULAR','ຢອດຕາ (Ocular)','Ocular'],['INTRANASAL','ຢອດດັງ (Intranasal)','Intranasal']
  ].map(([code,valueText,nameEn],i)=>({code,valueText,nameLo:valueText,nameEn,sortOrder:i+1})),
  atcvet:[
    ['QA','QA — ລະບົບຍ່ອຍອາຫານ & ເມຕາໂບລິຊຶມ','Alimentary tract and metabolism',[]],
    ['QB','QB — ເລືອດ & ອະໄວຍະວະສ້າງເລືອດ','Blood and blood forming organs',[]],
    ['QC','QC — ຫົວໃຈ & ຫຼອດເລືອດ','Cardiovascular system',[]],
    ['QD','QD — ຜິວໜັງ','Dermatologicals',['ANTIFUNGAL','ANTISEPTIC_DISINFECTANT']],
    ['QG','QG — ສືບພັນ & ຮໍໂມນເພດ','Genito urinary system and sex hormones',['HORMONAL_REPRODUCTIVE']],
    ['QH','QH — ຮໍໂມນລະບົບ','Systemic hormonal preparations',['HORMONAL_REPRODUCTIVE']],
    ['QI','QI — ວັກຊີນ/ຜະລິດຕະພັນພູມຄຸ້ມກັນ','Immunologicals',['VACCINE']],
    ['QJ','QJ — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','Antiinfectives for systemic use',['ANTIMICROBIAL','ANTIVIRAL','ANTIFUNGAL']],
    ['QJ01','QJ01 — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ (Antibacterials)','Antibacterials for systemic use',['ANTIMICROBIAL']],
    ['QJ05','QJ05 — ຢາຕ້ານໄວຣັດ (Antivirals)','Antivirals for systemic use',['ANTIVIRAL']],
    ['QJ51','QJ51 — ຢາຕ້ານເຊື້ອສອດເຕົ້ານົມ (Intramammary)','Antibacterials for intramammary use',['ANTIMICROBIAL']],
    ['QL','QL — ຢາຕ້ານເນື້ອງອກ/ປັບພູມ','Antineoplastic and immunomodulating agents',[]],
    ['QM','QM — ກ້າມ & ກະດູກ','Musculo-skeletal system',['ANTI_INFLAMMATORY_ANALGESIC']],
    ['QM01','QM01 — ຢາຕ້ານການອັກເສບ (NSAIDs)','Anti-inflammatory and antirheumatic products',['ANTI_INFLAMMATORY_ANALGESIC']],
    ['QN','QN — ລະບົບປະສາດ','Nervous system',['ANESTHETIC_SEDATIVE']],
    ['QN01','QN01 — ຢາສະຫຼົບ / ຢາຊາ (Anaesthetics)','Anaesthetics',['ANESTHETIC_SEDATIVE']],
    ['QN05','QN05 — ຢາລະງັບປະສາດ (Sedatives)','Sedatives',['ANESTHETIC_SEDATIVE']],
    ['QP','QP — ຢາຕ້ານກາຝາກ, ຂ້າແມງໄມ້','Antiparasitic products, insecticides and repellents',['ANTIPARASITIC']],
    ['QP51','QP51 — ຢາຕ້ານໂປຣໂຕຊົວ (Antiprotozoals)','Antiprotozoals',['ANTIPARASITIC']],
    ['QP52','QP52 — ຢາຖ່າຍພະຍາດ (Anthelmintics)','Anthelmintics',['ANTIPARASITIC']],
    ['QP53','QP53 — ຢາກຳຈັດກາຝາກຕົວນອກ ເຊັ່ນ ເຫັບ/ໝັດ (Ectoparasiticides)','Ectoparasiticides',['ANTIPARASITIC']],
    ['QP54','QP54 — ຢາກຳຈັດກາຝາກພາຍໃນ+ພາຍນອກ (Endectocides)','Endectocides',['ANTIPARASITIC']],
    ['QR','QR — ລະບົບຫາຍໃຈ','Respiratory system',[]],['QS','QS — ຕາ/ຫູ','Sensory organs',[]],['QV','QV — ອື່ນໆ (Various)','Various',['OTHER_SPECIFIC_THERAPY']]
  ].map(([code,valueText,nameEn,categoryCodes],i)=>({code,valueText,nameLo:valueText,nameEn,sortOrder:i+1,metadata:{categoryCodes}})),
  registrationTypes:[
    {code:'IMPORT',prefix:'F',nameLo:'ນຳເຂົ້າ',nameEn:'Imported'},
    {code:'DOMESTIC',prefix:'L',nameLo:'ຜະລິດພາຍໃນ',nameEn:'Domestic'},
    {code:'REPACK',prefix:'R',nameLo:'ນຳເຂົ້າມາບັນຈຸ/ແບ່ງບັນຈຸພາຍໃນ',nameEn:'Repacked'}
  ]
};
