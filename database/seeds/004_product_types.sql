INSERT INTO product.product_type(code,name_lo,name_en,is_active) VALUES
('VETERINARY_PHARMACEUTICAL','ຢາສັດ','Veterinary Pharmaceutical',TRUE),('VACCINE','ວັກຊີນ','Vaccine',TRUE),
('BIOLOGICAL','ຊີວະພັນ','Biological Product',TRUE),('DIAGNOSTIC_KIT','ຊຸດກວດວິນິດໄສ','Diagnostic Kit',TRUE),
('DISINFECTANT','ຢາຂ້າເຊື້ອ','Disinfectant',TRUE),('FEED','ອາຫານສັດ','Animal Feed',TRUE),('AQUAFEED','ອາຫານສັດນ້ຳ','Aquafeed',TRUE),
('FEED_ADDITIVE','ສານເສີມອາຫານສັດ','Feed Additive',TRUE),('PREMIX','ພຣີມິກ','Premix',TRUE),
('OTHER_REGULATED_PRODUCT','ຜະລິດຕະພັນຄວບຄຸມອື່ນ','Other Regulated Product',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;
