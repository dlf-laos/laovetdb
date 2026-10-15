INSERT INTO master.party_role_type(code,name_lo,name_en,allowed_party_kind,is_active) VALUES
('MANUFACTURER','ຜູ້ຜະລິດ','Manufacturer','COMPANY',TRUE),('IMPORTER','ຜູ້ນຳເຂົ້າ','Importer','COMPANY',TRUE),
('EXPORTER','ຜູ້ສົ່ງອອກ','Exporter','COMPANY',TRUE),('TRANSIT_OPERATOR','ຜູ້ດຳເນີນການສົ່ງຜ່ານ','Transit Operator','COMPANY',TRUE),
('DISTRIBUTOR','ຜູ້ຈຳໜ່າຍ','Distributor','COMPANY',TRUE),('FARM_OPERATOR','ຜູ້ດຳເນີນການຟາມ','Farm Operator',NULL,TRUE),
('FACILITY_OWNER','ເຈົ້າຂອງສະຖານທີ່','Facility Owner',NULL,TRUE),
('AUTHORIZED_REPRESENTATIVE','ຜູ້ຕາງໜ້າທີ່ໄດ້ຮັບອະນຸຍາດ','Authorized Representative',NULL,TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,allowed_party_kind=EXCLUDED.allowed_party_kind,is_active=TRUE;
