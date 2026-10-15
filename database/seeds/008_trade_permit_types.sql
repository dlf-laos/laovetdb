INSERT INTO trade.permit_type(code,name_lo,name_en,is_active) VALUES
('LIVE_ANIMAL_IMPORT','ອະນຸຍາດນຳເຂົ້າສັດມີຊີວິດ','Live Animal Import Permit',TRUE),
('ANIMAL_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດ','Animal Product Import Permit',TRUE),
('AQUATIC_ANIMAL_IMPORT','ອະນຸຍາດນຳເຂົ້າສັດນ້ຳ','Aquatic Animal Import Permit',TRUE),
('AQUATIC_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດນ້ຳ','Aquatic Product Import Permit',TRUE),
('VETERINARY_PRODUCT_IMPORT','ອະນຸຍາດນຳເຂົ້າຜະລິດຕະພັນສັດຕະວະແພດ','Veterinary Product Import Permit',TRUE),
('FEED_IMPORT','ອະນຸຍາດນຳເຂົ້າອາຫານສັດ','Feed Import Permit',TRUE),('EXPORT','ອະນຸຍາດສົ່ງອອກ','Export Authorization',TRUE),
('TRANSIT','ອະນຸຍາດສົ່ງຜ່ານ','Transit Authorization',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;
