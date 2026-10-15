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
