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
