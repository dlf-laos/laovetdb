INSERT INTO lookup.admin_unit_type(code,level_no,name_lo,name_en,is_active) VALUES
('COUNTRY',0,'ປະເທດ','Country',TRUE),('PROVINCE',1,'ແຂວງ/ນະຄອນຫຼວງ','Province/Capital',TRUE),
('DISTRICT',2,'ເມືອງ','District',TRUE),('COMMUNE',3,'ຕາແສງ','Commune',TRUE),('VILLAGE',4,'ບ້ານ','Village',TRUE)
ON CONFLICT(code) DO UPDATE SET level_no=EXCLUDED.level_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;
