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
