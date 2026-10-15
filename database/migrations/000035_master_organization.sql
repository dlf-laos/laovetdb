CREATE TABLE master.organization (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), parent_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 organization_code VARCHAR(100), organization_type VARCHAR(50) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, valid_from DATE, valid_to DATE,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_org_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_org_code ON master.organization(organization_code) WHERE organization_code IS NOT NULL;
CREATE INDEX idx_org_parent ON master.organization(parent_id); CREATE INDEX idx_org_admin_unit ON master.organization(admin_unit_id);
CREATE TRIGGER trg_org_updated_at BEFORE UPDATE ON master.organization FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
ALTER TABLE system.number_sequence ADD CONSTRAINT fk_number_sequence_org FOREIGN KEY(organization_id) REFERENCES master.organization(id) ON DELETE RESTRICT;
