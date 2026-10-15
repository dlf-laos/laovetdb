CREATE TABLE fisheries.stock_batch (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), batch_no VARCHAR(120) NOT NULL UNIQUE,
 facility_id UUID NOT NULL REFERENCES fisheries.aquaculture_facility(facility_id) ON DELETE RESTRICT,
 aquaculture_unit_id UUID REFERENCES fisheries.aquaculture_unit(id) ON DELETE RESTRICT, species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT,
 initial_quantity BIGINT CHECK(initial_quantity IS NULL OR initial_quantity>=0), stocking_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE fisheries.production_record (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), stock_batch_id UUID NOT NULL REFERENCES fisheries.stock_batch(id) ON DELETE RESTRICT,
 record_date DATE NOT NULL, estimated_quantity BIGINT CHECK(estimated_quantity IS NULL OR estimated_quantity>=0), estimated_biomass NUMERIC(20,6),
 biomass_unit VARCHAR(30), mortality_quantity BIGINT CHECK(mortality_quantity IS NULL OR mortality_quantity>=0), notes TEXT);
CREATE TABLE fisheries.harvest (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), stock_batch_id UUID NOT NULL REFERENCES fisheries.stock_batch(id) ON DELETE RESTRICT,
 harvested_at TIMESTAMPTZ NOT NULL, quantity NUMERIC(20,6), unit_code VARCHAR(30), destination_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 CONSTRAINT ck_harvest_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE INDEX idx_stock_batch_facility ON fisheries.stock_batch(facility_id,status); CREATE INDEX idx_aquatic_production_date ON fisheries.production_record(stock_batch_id,record_date DESC);
