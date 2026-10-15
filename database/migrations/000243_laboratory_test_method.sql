CREATE TABLE laboratory.test_method (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), method_code VARCHAR(100) NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 name_lo TEXT, name_en TEXT NOT NULL, reference_standard TEXT, effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 UNIQUE(method_code,version_no), CONSTRAINT ck_test_method_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
