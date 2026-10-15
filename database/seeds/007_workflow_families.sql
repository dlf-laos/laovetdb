INSERT INTO workflow.definition(workflow_code,name_lo,name_en,is_active) VALUES
('WF-001','ການຂຶ້ນທະບຽນທົ່ວໄປ','Generic Registration',TRUE),('WF-002','ການອະນຸຍາດທົ່ວໄປ','Generic Licensing',TRUE),
('WF-003','ຂຶ້ນທະບຽນຜະລິດຕະພັນ','Product Registration',TRUE),('WF-004','ສ້າງຕັ້ງໂຮງງານ/ສະຖານທີ່','Factory Establishment',TRUE),
('WF-005','ການປະເມີນ GMP/ເຕັກນິກ','GMP / Technical Certification',TRUE),('WF-006','ນຳເຂົ້າ/ສົ່ງອອກ/ສົ່ງຜ່ານ','Import / Export / Transit',TRUE),
('WF-007','ກວດກາ ແລະ CAPA','Inspection & CAPA',TRUE),('WF-008','ການທົດສອບຫ້ອງວິໄຈ','Laboratory Testing',TRUE),
('WF-009','ສືບສວນພະຍາດ/ການລະບາດ','Disease Investigation & Outbreak',TRUE),('WF-010','ການເຄື່ອນຍ້າຍສັດ','Animal Movement',TRUE),
('WF-011','ການບັງຄັບລະບຽບ','Regulatory Enforcement',TRUE),('WF-012','ປ່ຽນແປງຂໍ້ມູນຫຼັກ','Master Data Change',TRUE)
ON CONFLICT(workflow_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;
