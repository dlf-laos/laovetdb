CREATE TABLE registration.product_registration_package (registration_id UUID NOT NULL REFERENCES registration.registration(id) ON DELETE RESTRICT,
 package_id UUID NOT NULL REFERENCES product.package(id) ON DELETE RESTRICT, registration_package_no VARCHAR(120), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 PRIMARY KEY(registration_id,package_id));
CREATE UNIQUE INDEX uq_registration_package_no ON registration.product_registration_package(registration_package_no) WHERE registration_package_no IS NOT NULL;
