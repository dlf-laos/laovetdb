
-- ============================================================================
-- MIGRATION: 000001_extensions.sql
-- ============================================================================
-- LVSP migration 000001: extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS unaccent;
-- Spatial features. Keep in this migration only when the selected Neon/Postgres environment supports PostGIS.
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- MIGRATION: 000002_schemas.sql
-- ============================================================================
-- LVSP migration 000002: schemas
CREATE SCHEMA IF NOT EXISTS system;
CREATE SCHEMA IF NOT EXISTS lookup;
CREATE SCHEMA IF NOT EXISTS master;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS document;
CREATE SCHEMA IF NOT EXISTS casework;
CREATE SCHEMA IF NOT EXISTS registration;
CREATE SCHEMA IF NOT EXISTS licensing;
CREATE SCHEMA IF NOT EXISTS facility;
CREATE SCHEMA IF NOT EXISTS product;
CREATE SCHEMA IF NOT EXISTS feed;
CREATE SCHEMA IF NOT EXISTS farm;
CREATE SCHEMA IF NOT EXISTS animal;
CREATE SCHEMA IF NOT EXISTS disease;
CREATE SCHEMA IF NOT EXISTS laboratory;
CREATE SCHEMA IF NOT EXISTS fisheries;
CREATE SCHEMA IF NOT EXISTS trade;
CREATE SCHEMA IF NOT EXISTS inspection;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS enforcement;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS gis;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- ============================================================================
-- MIGRATION: 000003_common_functions.sql
-- ============================================================================
-- LVSP migration 000003: common technical/integrity functions
CREATE OR REPLACE FUNCTION system.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION system.prevent_hard_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete is not allowed on %.%', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$;

CREATE OR REPLACE FUNCTION system.prevent_change_if_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = ANY (TG_ARGV) THEN
        RAISE EXCEPTION 'Record in status % is immutable in %.%', OLD.status, TG_TABLE_SCHEMA, TG_TABLE_NAME;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

-- Technical migration ledger. This is infrastructure metadata, not a business table.
CREATE TABLE IF NOT EXISTS system.schema_migration (
    migration_name  TEXT PRIMARY KEY,
    sha256_checksum CHAR(64) NOT NULL,
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_by      TEXT NOT NULL DEFAULT current_user
);

-- ============================================================================
-- MIGRATION: 000010_system_numbering.sql
-- ============================================================================
CREATE TABLE system.number_sequence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_code VARCHAR(100) NOT NULL,
    organization_id UUID,
    year_value INTEGER,
    prefix VARCHAR(100),
    suffix VARCHAR(100),
    next_value BIGINT NOT NULL DEFAULT 1 CHECK (next_value > 0),
    padding_length INTEGER NOT NULL DEFAULT 6 CHECK (padding_length BETWEEN 1 AND 30),
    reset_rule VARCHAR(30) NOT NULL DEFAULT 'NEVER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID
);

-- NULLs in a normal UNIQUE constraint do not prevent multiple otherwise-identical global sequences.
-- Use an expression unique index so NULL scope values normalize consistently.
CREATE UNIQUE INDEX uq_number_sequence_scope
ON system.number_sequence (
    sequence_code,
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(year_value, -1)
);

CREATE TRIGGER trg_number_sequence_updated_at
BEFORE UPDATE ON system.number_sequence
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- Atomic business-number allocation. The format itself remains configuration-driven.
CREATE OR REPLACE FUNCTION system.next_business_number(
    p_sequence_code VARCHAR,
    p_organization_id UUID DEFAULT NULL,
    p_year_value INTEGER DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    r system.number_sequence%ROWTYPE;
    v BIGINT;
BEGIN
    SELECT * INTO r
    FROM system.number_sequence
    WHERE sequence_code = p_sequence_code
      AND organization_id IS NOT DISTINCT FROM p_organization_id
      AND year_value IS NOT DISTINCT FROM p_year_value
      AND is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active number sequence not found: %, org %, year %', p_sequence_code, p_organization_id, p_year_value;
    END IF;

    v := r.next_value;
    UPDATE system.number_sequence SET next_value = next_value + 1 WHERE id = r.id;
    RETURN COALESCE(r.prefix, '') || LPAD(v::TEXT, r.padding_length, '0') || COALESCE(r.suffix, '');
END;
$$;

-- ============================================================================
-- MIGRATION: 000011_system_legal.sql
-- ============================================================================
CREATE TABLE system.legal_instrument (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), instrument_code VARCHAR(100), instrument_type VARCHAR(100) NOT NULL,
 title_lo TEXT NOT NULL, title_en TEXT, issuing_authority TEXT, issue_date DATE, effective_from DATE, effective_to DATE,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', source_url TEXT, verification_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
 verified_at TIMESTAMPTZ, verified_by UUID, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_legal_dates CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from));
CREATE UNIQUE INDEX uq_legal_instrument_code ON system.legal_instrument(instrument_code) WHERE instrument_code IS NOT NULL;
CREATE TABLE system.regulatory_rule (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), rule_code VARCHAR(100) NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 rule_type VARCHAR(50) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT, description TEXT,
 legal_instrument_id UUID REFERENCES system.legal_instrument(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ NOT NULL,
 effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', configuration JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID,
 UNIQUE(rule_code,version_no), CONSTRAINT ck_reg_rule_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_reg_rule_legal ON system.regulatory_rule(legal_instrument_id);
CREATE INDEX idx_reg_rule_effective ON system.regulatory_rule(rule_code,effective_from,effective_to);
CREATE TRIGGER trg_legal_instrument_updated_at BEFORE UPDATE ON system.legal_instrument FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000012_system_services.sql
-- ============================================================================
CREATE TABLE system.service_definition (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), service_code VARCHAR(50) NOT NULL UNIQUE, domain_code VARCHAR(50) NOT NULL,
 name_lo TEXT NOT NULL, name_en TEXT, description TEXT, applicant_type VARCHAR(50), is_public BOOLEAN NOT NULL DEFAULT FALSE,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE system.service_version (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), service_id UUID NOT NULL REFERENCES system.service_definition(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 workflow_code VARCHAR(100), sla_configuration JSONB, requirements JSONB, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(service_id,version_no),
 CONSTRAINT ck_service_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_service_domain ON system.service_definition(domain_code);
CREATE TRIGGER trg_service_definition_updated_at BEFORE UPDATE ON system.service_definition FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000020_lookup_country.sql
-- ============================================================================
CREATE TABLE lookup.country (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), iso2_code CHAR(2) UNIQUE, iso3_code CHAR(3) UNIQUE,
 numeric_code VARCHAR(3), name_lo TEXT NOT NULL, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);

-- ============================================================================
-- MIGRATION: 000021_lookup_admin_unit_type.sql
-- ============================================================================
CREATE TABLE lookup.admin_unit_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(30) NOT NULL UNIQUE,
 level_no INTEGER NOT NULL CHECK(level_no>=0), name_lo TEXT NOT NULL, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE UNIQUE INDEX uq_admin_unit_type_level ON lookup.admin_unit_type(level_no) WHERE is_active=TRUE;

-- ============================================================================
-- MIGRATION: 000022_lookup_species.sql
-- ============================================================================
CREATE TABLE lookup.species (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, scientific_name TEXT,
 name_lo TEXT NOT NULL, name_en TEXT, tracking_mode VARCHAR(30) NOT NULL DEFAULT 'CONFIGURABLE', is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT ck_species_tracking_mode CHECK(tracking_mode IN ('INDIVIDUAL','GROUP','BOTH','CONFIGURABLE')));

-- ============================================================================
-- MIGRATION: 000023_lookup_facility_type.sql
-- ============================================================================
CREATE TABLE lookup.facility_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);

-- ============================================================================
-- MIGRATION: 000030_master_geography.sql
-- ============================================================================
CREATE TABLE master.admin_unit (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), parent_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 admin_unit_type_id UUID NOT NULL REFERENCES lookup.admin_unit_type(id) ON DELETE RESTRICT,
 country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, official_code VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT,
 valid_from DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', geometry geometry(MultiPolygon,4326),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID,
 CONSTRAINT ck_admin_unit_validity CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_admin_unit_code ON master.admin_unit(official_code) WHERE official_code IS NOT NULL;
CREATE INDEX idx_admin_unit_parent ON master.admin_unit(parent_id); CREATE INDEX idx_admin_unit_type ON master.admin_unit(admin_unit_type_id);
CREATE INDEX idx_admin_unit_geometry ON master.admin_unit USING GIST(geometry);
CREATE INDEX idx_admin_unit_name_lo_trgm ON master.admin_unit USING GIN(name_lo gin_trgm_ops);
CREATE TRIGGER trg_admin_unit_updated_at BEFORE UPDATE ON master.admin_unit FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000031_master_party.sql
-- ============================================================================
CREATE TABLE master.party (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_kind VARCHAR(20) NOT NULL,
 display_name TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID,
 CONSTRAINT ck_party_kind CHECK(party_kind IN ('PERSON','COMPANY')));
CREATE INDEX idx_party_kind_status ON master.party(party_kind,status);
CREATE INDEX idx_party_display_name_trgm ON master.party USING GIN(display_name gin_trgm_ops);
CREATE TRIGGER trg_party_updated_at BEFORE UPDATE ON master.party FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000032_master_person.sql
-- ============================================================================
CREATE TABLE master.person (party_id UUID PRIMARY KEY REFERENCES master.party(id) ON DELETE RESTRICT, first_name_lo TEXT, last_name_lo TEXT,
 first_name_en TEXT, last_name_en TEXT, date_of_birth DATE, phone VARCHAR(50), email CITEXT,
 nationality_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_person_email ON master.person(email) WHERE email IS NOT NULL;
CREATE TRIGGER trg_person_updated_at BEFORE UPDATE ON master.person FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE OR REPLACE FUNCTION master.enforce_person_party_kind()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master.party p WHERE p.id = NEW.party_id AND p.party_kind = 'PERSON') THEN
        RAISE EXCEPTION 'party_id % is not a PERSON party', NEW.party_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_person_party_kind BEFORE INSERT OR UPDATE OF party_id ON master.person
FOR EACH ROW EXECUTE FUNCTION master.enforce_person_party_kind();

-- ============================================================================
-- MIGRATION: 000033_master_company.sql
-- ============================================================================
CREATE TABLE master.company (party_id UUID PRIMARY KEY REFERENCES master.party(id) ON DELETE RESTRICT, legal_name_lo TEXT NOT NULL,
 legal_name_en TEXT, enterprise_no VARCHAR(100), tax_no VARCHAR(100), country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 registration_date DATE, phone VARCHAR(50), email CITEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_company_enterprise_no ON master.company(enterprise_no) WHERE enterprise_no IS NOT NULL;
CREATE INDEX idx_company_name_lo_trgm ON master.company USING GIN(legal_name_lo gin_trgm_ops);
CREATE INDEX idx_company_name_en_trgm ON master.company USING GIN(legal_name_en gin_trgm_ops);
CREATE TRIGGER trg_company_updated_at BEFORE UPDATE ON master.company FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE OR REPLACE FUNCTION master.enforce_company_party_kind()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master.party p WHERE p.id = NEW.party_id AND p.party_kind = 'COMPANY') THEN
        RAISE EXCEPTION 'party_id % is not a COMPANY party', NEW.party_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_company_party_kind BEFORE INSERT OR UPDATE OF party_id ON master.company
FOR EACH ROW EXECUTE FUNCTION master.enforce_company_party_kind();

-- ============================================================================
-- MIGRATION: 000034_master_party_roles.sql
-- ============================================================================
CREATE TABLE master.party_role_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(50) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, allowed_party_kind VARCHAR(20), is_active BOOLEAN NOT NULL DEFAULT TRUE,
 CONSTRAINT ck_role_party_kind CHECK(allowed_party_kind IS NULL OR allowed_party_kind IN ('PERSON','COMPANY')));
CREATE TABLE master.party_role_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 role_type_id UUID NOT NULL REFERENCES master.party_role_type(id) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_party_role_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_party_role_party ON master.party_role_assignment(party_id,status);
CREATE INDEX idx_party_role_type ON master.party_role_assignment(role_type_id,status);

-- ============================================================================
-- MIGRATION: 000035_master_organization.sql
-- ============================================================================
CREATE TABLE master.organization (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), parent_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 organization_code VARCHAR(100), organization_type VARCHAR(50) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, valid_from DATE, valid_to DATE,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_org_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_org_code ON master.organization(organization_code) WHERE organization_code IS NOT NULL;
CREATE INDEX idx_org_parent ON master.organization(parent_id); CREATE INDEX idx_org_admin_unit ON master.organization(admin_unit_id);
CREATE TRIGGER trg_org_updated_at BEFORE UPDATE ON master.organization FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
ALTER TABLE system.number_sequence ADD CONSTRAINT fk_number_sequence_org FOREIGN KEY(organization_id) REFERENCES master.organization(id) ON DELETE RESTRICT;

-- ============================================================================
-- MIGRATION: 000036_master_facility.sql
-- ============================================================================
CREATE TABLE master.facility (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_no VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, address_text_lo TEXT, address_text_en TEXT,
 location geography(Point,4326), status VARCHAR(30) NOT NULL DEFAULT 'PROPOSED', established_date DATE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID, updated_by UUID);
CREATE UNIQUE INDEX uq_facility_no ON master.facility(facility_no) WHERE facility_no IS NOT NULL;
CREATE INDEX idx_facility_admin_unit ON master.facility(admin_unit_id); CREATE INDEX idx_facility_location ON master.facility USING GIST(location);
CREATE INDEX idx_facility_name_lo_trgm ON master.facility USING GIN(name_lo gin_trgm_ops);
CREATE TRIGGER trg_facility_updated_at BEFORE UPDATE ON master.facility FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
CREATE TABLE master.facility_type_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 facility_type_id UUID NOT NULL REFERENCES lookup.facility_type(id) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_facility_type_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE TABLE master.facility_party_role (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, role_code VARCHAR(50) NOT NULL REFERENCES master.party_role_type(code) ON DELETE RESTRICT, valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
 valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_facility_party_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_facility_type_assignment ON master.facility_type_assignment(facility_id,status);
CREATE INDEX idx_facility_party_role ON master.facility_party_role(facility_id,role_code,status);

-- ============================================================================
-- MIGRATION: 000037_master_facility_components.sql
-- ============================================================================
CREATE TABLE master.facility_component (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 parent_component_id UUID REFERENCES master.facility_component(id) ON DELETE RESTRICT, component_type VARCHAR(50) NOT NULL,
 component_code VARCHAR(100), name_lo TEXT NOT NULL, name_en TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_facility_component_code ON master.facility_component(facility_id,component_code) WHERE component_code IS NOT NULL;
CREATE INDEX idx_facility_component_facility ON master.facility_component(facility_id);

-- ============================================================================
-- MIGRATION: 000040_security_users.sql
-- ============================================================================
CREATE TABLE security.app_user (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), person_party_id UUID REFERENCES master.person(party_id) ON DELETE RESTRICT,
 external_subject TEXT UNIQUE, username CITEXT UNIQUE, email CITEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', last_login_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_app_user_email ON security.app_user(email) WHERE email IS NOT NULL;
CREATE TRIGGER trg_app_user_updated_at BEFORE UPDATE ON security.app_user FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000041_security_roles_permissions.sql
-- ============================================================================
CREATE TABLE security.role (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 is_system_role BOOLEAN NOT NULL DEFAULT FALSE, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE security.permission (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(150) NOT NULL UNIQUE, description TEXT);
CREATE TABLE security.role_permission (role_id UUID NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
 permission_id UUID NOT NULL REFERENCES security.permission(id) ON DELETE CASCADE, PRIMARY KEY(role_id,permission_id));

-- ============================================================================
-- MIGRATION: 000042_security_scope_delegation.sql
-- ============================================================================
CREATE TABLE security.access_scope (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT, domain_code VARCHAR(100), is_global BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_scope_target CHECK(is_global OR organization_id IS NOT NULL OR admin_unit_id IS NOT NULL OR domain_code IS NOT NULL));
CREATE TABLE security.user_role_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT,
 role_id UUID NOT NULL REFERENCES security.role(id) ON DELETE RESTRICT, access_scope_id UUID REFERENCES security.access_scope(id) ON DELETE RESTRICT,
 valid_from TIMESTAMPTZ NOT NULL DEFAULT now(), valid_to TIMESTAMPTZ, assigned_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_user_role_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE TABLE security.delegation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), delegator_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT,
 delegate_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, role_id UUID REFERENCES security.role(id) ON DELETE RESTRICT,
 access_scope_id UUID REFERENCES security.access_scope(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ NOT NULL,
 authority_reference TEXT, reason TEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_delegation_time CHECK(effective_to>effective_from), CONSTRAINT ck_delegation_users CHECK(delegator_user_id<>delegate_user_id));
CREATE INDEX idx_user_role_user ON security.user_role_assignment(user_id,status,valid_to);
CREATE INDEX idx_delegation_delegate ON security.delegation(delegate_user_id,status,effective_to);

-- ============================================================================
-- MIGRATION: 000050_workflow_definition.sql
-- ============================================================================
CREATE TABLE workflow.definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE workflow.definition_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), definition_id UUID NOT NULL REFERENCES workflow.definition(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(definition_id,version_no), CONSTRAINT ck_workflow_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE workflow.step (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE CASCADE,
 step_code VARCHAR(100) NOT NULL, name_lo TEXT NOT NULL, name_en TEXT, step_type VARCHAR(50) NOT NULL, sequence_no INTEGER, configuration JSONB,
 UNIQUE(workflow_version_id,step_code));
CREATE TABLE workflow.transition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE CASCADE,
 transition_code VARCHAR(100) NOT NULL, from_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT,
 to_step_id UUID NOT NULL REFERENCES workflow.step(id) ON DELETE RESTRICT, required_permission VARCHAR(150), rule_configuration JSONB,
 UNIQUE(workflow_version_id,transition_code));

-- ============================================================================
-- MIGRATION: 000051_workflow_runtime.sql
-- ============================================================================
CREATE TABLE workflow.instance (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_version_id UUID NOT NULL REFERENCES workflow.definition_version(id) ON DELETE RESTRICT,
 service_id UUID REFERENCES system.service_definition(id) ON DELETE RESTRICT, business_entity_type VARCHAR(100) NOT NULL, business_entity_id UUID NOT NULL,
 current_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL, started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 completed_at TIMESTAMPTZ, started_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE TABLE workflow.task (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_instance_id UUID NOT NULL REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 step_id UUID NOT NULL REFERENCES workflow.step(id) ON DELETE RESTRICT, assigned_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 assigned_role_id UUID REFERENCES security.role(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', due_at TIMESTAMPTZ,
 completed_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE workflow.action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), workflow_instance_id UUID NOT NULL REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 task_id UUID REFERENCES workflow.task(id) ON DELETE RESTRICT, action_code VARCHAR(100) NOT NULL,
 from_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT, to_step_id UUID REFERENCES workflow.step(id) ON DELETE RESTRICT,
 actor_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, comment TEXT, performed_at TIMESTAMPTZ NOT NULL DEFAULT now(), metadata JSONB);
CREATE INDEX idx_workflow_task_user_status ON workflow.task(assigned_user_id,status);
CREATE INDEX idx_workflow_task_due ON workflow.task(due_at) WHERE status='OPEN';
CREATE INDEX idx_workflow_action_instance_time ON workflow.action(workflow_instance_id,performed_at);

-- ============================================================================
-- MIGRATION: 000060_document_storage.sql
-- ============================================================================
CREATE TABLE document.document (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), document_type VARCHAR(100) NOT NULL, title TEXT,
 classification VARCHAR(30) NOT NULL DEFAULT 'INTERNAL', business_entity_type VARCHAR(100), business_entity_id UUID,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE TABLE document.file (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), document_id UUID NOT NULL REFERENCES document.document(id) ON DELETE RESTRICT,
 storage_provider VARCHAR(50) NOT NULL, object_key TEXT NOT NULL, original_filename TEXT, mime_type VARCHAR(255), size_bytes BIGINT CHECK(size_bytes IS NULL OR size_bytes>=0),
 sha256_checksum VARCHAR(64), uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), uploaded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 UNIQUE(storage_provider,object_key));
CREATE INDEX idx_document_business_entity ON document.document(business_entity_type,business_entity_id);

-- ============================================================================
-- MIGRATION: 000061_document_templates.sql
-- ============================================================================
CREATE TABLE document.template (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, document_type VARCHAR(100) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE document.template_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_id UUID NOT NULL REFERENCES document.template(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), language_code VARCHAR(10) NOT NULL, effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 template_body TEXT, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(template_id,version_no,language_code),
 CONSTRAINT ck_template_dates CHECK(effective_to IS NULL OR effective_to>effective_from));

-- ============================================================================
-- MIGRATION: 000070_audit.sql
-- ============================================================================
CREATE TABLE audit.event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 actor_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, action_code VARCHAR(100) NOT NULL, resource_type VARCHAR(100), resource_id UUID,
 request_id UUID, correlation_id UUID, ip_address INET, before_data JSONB, after_data JSONB, metadata JSONB);
CREATE INDEX idx_audit_event_time ON audit.event(occurred_at DESC); CREATE INDEX idx_audit_resource ON audit.event(resource_type,resource_id);
CREATE INDEX idx_audit_correlation ON audit.event(correlation_id); CREATE INDEX idx_audit_actor ON audit.event(actor_user_id,occurred_at DESC);

-- ============================================================================
-- MIGRATION: 000080_integration_outbox_inbox.sql
-- ============================================================================
CREATE TABLE integration.outbox_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_type VARCHAR(150) NOT NULL, aggregate_type VARCHAR(100) NOT NULL,
 aggregate_id UUID NOT NULL, schema_version INTEGER NOT NULL DEFAULT 1 CHECK(schema_version>0), correlation_id UUID, payload JSONB NOT NULL,
 occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(), published_at TIMESTAMPTZ, attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count>=0), last_error TEXT);
CREATE INDEX idx_outbox_unpublished ON integration.outbox_event(occurred_at) WHERE published_at IS NULL;
CREATE TABLE integration.inbox_message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), external_message_id VARCHAR(255) NOT NULL,
 source_system VARCHAR(100) NOT NULL, message_type VARCHAR(150), received_at TIMESTAMPTZ NOT NULL DEFAULT now(), processed_at TIMESTAMPTZ,
 processing_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED', payload JSONB, UNIQUE(source_system,external_message_id));
CREATE INDEX idx_inbox_unprocessed ON integration.inbox_message(received_at) WHERE processed_at IS NULL;

-- ============================================================================
-- MIGRATION: 000100_casework.sql
-- ============================================================================
CREATE TABLE casework.regulatory_case (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_no VARCHAR(100) NOT NULL UNIQUE,
 service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
 applicant_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 workflow_instance_id UUID REFERENCES workflow.instance(id) ON DELETE RESTRICT,
 status VARCHAR(40) NOT NULL DEFAULT 'DRAFT', priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', source_channel VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
 submitted_at TIMESTAMPTZ, received_at TIMESTAMPTZ, completed_at TIMESTAMPTZ,
 assigned_org_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_case_dates CHECK(completed_at IS NULL OR submitted_at IS NULL OR completed_at>=submitted_at));
CREATE TABLE casework.application (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL UNIQUE REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 application_type VARCHAR(50) NOT NULL, declaration_accepted BOOLEAN NOT NULL DEFAULT FALSE, declaration_at TIMESTAMPTZ,
 applicant_reference VARCHAR(150), submitted_payload JSONB, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE casework.case_party (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, role_code VARCHAR(50) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE casework.information_request (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 request_no INTEGER NOT NULL CHECK(request_no>0), requested_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), due_at TIMESTAMPTZ, subject TEXT NOT NULL, details TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'OPEN', responded_at TIMESTAMPTZ, UNIQUE(case_id,request_no));
CREATE TABLE casework.regulatory_decision (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_no VARCHAR(100), decision_type VARCHAR(50) NOT NULL, decision_date TIMESTAMPTZ NOT NULL, effective_from TIMESTAMPTZ, effective_to TIMESTAMPTZ,
 regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT,
 authority_org_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 authority_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, reason TEXT, conditions TEXT,
 supersedes_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ISSUED',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_decision_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE UNIQUE INDEX uq_decision_no ON casework.regulatory_decision(decision_no) WHERE decision_no IS NOT NULL;
CREATE INDEX idx_case_applicant ON casework.regulatory_case(applicant_party_id); CREATE INDEX idx_case_status_created ON casework.regulatory_case(status,created_at DESC);
CREATE INDEX idx_case_service ON casework.regulatory_case(service_version_id); CREATE INDEX idx_decision_case ON casework.regulatory_decision(case_id,decision_date DESC);
CREATE TRIGGER trg_regulatory_case_updated_at BEFORE UPDATE ON casework.regulatory_case FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000110_registration.sql
-- ============================================================================
CREATE TABLE registration.registration_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE registration.registration (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), registration_no VARCHAR(120) NOT NULL UNIQUE,
 registration_type_id UUID NOT NULL REFERENCES registration.registration_type(id) ON DELETE RESTRICT,
 holder_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, effective_from DATE, expiry_date DATE, status VARCHAR(30) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_registration_dates CHECK(expiry_date IS NULL OR effective_from IS NULL OR expiry_date>=effective_from));
CREATE TABLE registration.product_registration (registration_id UUID PRIMARY KEY REFERENCES registration.registration(id) ON DELETE RESTRICT,
 product_id UUID NOT NULL, registration_scope JSONB);
CREATE TABLE registration.registration_action (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), registration_id UUID NOT NULL REFERENCES registration.registration(id) ON DELETE RESTRICT,
 action_type VARCHAR(40) NOT NULL, case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_at TIMESTAMPTZ, details JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_registration_holder ON registration.registration(holder_party_id); CREATE INDEX idx_registration_expiry ON registration.registration(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_registration_action ON registration.registration_action(registration_id,created_at);

-- ============================================================================
-- MIGRATION: 000120_licensing.sql
-- ============================================================================
CREATE TABLE licensing.license_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE licensing.license (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), license_no VARCHAR(120) NOT NULL UNIQUE,
 license_type_id UUID NOT NULL REFERENCES licensing.license_type(id) ON DELETE RESTRICT,
 holder_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, effective_from DATE, expiry_date DATE, status VARCHAR(30) NOT NULL, conditions TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_license_dates CHECK(expiry_date IS NULL OR effective_from IS NULL OR expiry_date>=effective_from));
CREATE TABLE licensing.facility_license (license_id UUID PRIMARY KEY REFERENCES licensing.license(id) ON DELETE RESTRICT,
 facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT, activity_code VARCHAR(100), scope_details JSONB);
CREATE TABLE licensing.license_action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), license_id UUID NOT NULL REFERENCES licensing.license(id) ON DELETE RESTRICT,
 action_type VARCHAR(40) NOT NULL, case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_at TIMESTAMPTZ NOT NULL, reason TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_license_holder ON licensing.license(holder_party_id); CREATE INDEX idx_license_expiry ON licensing.license(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_facility_license_facility ON licensing.facility_license(facility_id);

-- ============================================================================
-- MIGRATION: 000130_certificate_foundation.sql
-- ============================================================================
CREATE TABLE document.certificate (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), certificate_no VARCHAR(120) NOT NULL UNIQUE, certificate_type VARCHAR(100) NOT NULL,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 source_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 template_version_id UUID REFERENCES document.template_version(id) ON DELETE RESTRICT, issued_at TIMESTAMPTZ NOT NULL,
 valid_from TIMESTAMPTZ, valid_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL, verification_token VARCHAR(160) UNIQUE,
 generated_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 supersedes_certificate_id UUID REFERENCES document.certificate(id) ON DELETE RESTRICT,
 revoked_by_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_certificate_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_certificate_status_validity ON document.certificate(status,valid_to); CREATE INDEX idx_certificate_case ON document.certificate(source_case_id);

-- ============================================================================
-- MIGRATION: 000140_facility_establishment.sql
-- ============================================================================
CREATE TABLE facility.establishment_application (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_id UUID NOT NULL UNIQUE REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
 proposed_facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT, establishment_type VARCHAR(100) NOT NULL,
 proposed_capacity TEXT, technical_summary TEXT, status VARCHAR(30) NOT NULL DEFAULT 'UNDER_REVIEW', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE facility.external_approval (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 approval_type VARCHAR(100) NOT NULL, issuing_agency TEXT, reference_no VARCHAR(150), issue_date DATE, expiry_date DATE,
 document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, verification_status VARCHAR(30) NOT NULL DEFAULT 'UNVERIFIED',
 verified_at TIMESTAMPTZ, verified_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_external_approval_dates CHECK(expiry_date IS NULL OR issue_date IS NULL OR expiry_date>=issue_date));
CREATE INDEX idx_establishment_facility ON facility.establishment_application(proposed_facility_id); CREATE INDEX idx_external_approval_facility ON facility.external_approval(facility_id,approval_type);

-- ============================================================================
-- MIGRATION: 000141_factory_profile.sql
-- ============================================================================
CREATE TABLE facility.factory_profile (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 factory_category VARCHAR(100) NOT NULL, commissioning_date DATE, production_capacity TEXT, quality_unit_present BOOLEAN,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');

-- ============================================================================
-- MIGRATION: 000142_production_line.sql
-- ============================================================================
CREATE TABLE facility.production_line (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 component_id UUID REFERENCES master.facility_component(id) ON DELETE RESTRICT, line_code VARCHAR(100), line_type VARCHAR(100) NOT NULL,
 name_lo TEXT, name_en TEXT, commissioned_at DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_production_line_code ON facility.production_line(facility_id,line_code) WHERE line_code IS NOT NULL;
CREATE INDEX idx_production_line_facility ON facility.production_line(facility_id,status);

-- ============================================================================
-- MIGRATION: 000143_gmp.sql
-- ============================================================================
CREATE TABLE facility.gmp_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 inspection_case_id UUID, assessment_type VARCHAR(50) NOT NULL, standard_reference TEXT, assessment_date DATE, result VARCHAR(30),
 decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE facility.gmp_scope (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), gmp_assessment_id UUID NOT NULL REFERENCES facility.gmp_assessment(id) ON DELETE RESTRICT,
 production_line_id UUID REFERENCES facility.production_line(id) ON DELETE RESTRICT, scope_code VARCHAR(100), scope_description TEXT);
CREATE INDEX idx_gmp_facility ON facility.gmp_assessment(facility_id,status);

-- ============================================================================
-- MIGRATION: 000150_product_reference.sql
-- ============================================================================
CREATE TABLE product.product_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE product.ingredient (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), ingredient_code VARCHAR(100) UNIQUE, name_lo TEXT, name_en TEXT NOT NULL, ingredient_type VARCHAR(50), is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE lookup.unit_of_measure (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(30) NOT NULL UNIQUE, name_lo TEXT, name_en TEXT NOT NULL, dimension_code VARCHAR(30), is_active BOOLEAN NOT NULL DEFAULT TRUE);

-- ============================================================================
-- MIGRATION: 000151_product_master.sql
-- ============================================================================
CREATE TABLE product.product (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_code VARCHAR(100), product_type_id UUID NOT NULL REFERENCES product.product_type(id) ON DELETE RESTRICT,
 trade_name TEXT NOT NULL, generic_name TEXT, lifecycle_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT);
CREATE UNIQUE INDEX uq_product_code ON product.product(product_code) WHERE product_code IS NOT NULL;
CREATE INDEX idx_product_trade_name_trgm ON product.product USING GIN(trade_name gin_trgm_ops); CREATE INDEX idx_product_type ON product.product(product_type_id);
CREATE TRIGGER trg_product_updated_at BEFORE UPDATE ON product.product FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
ALTER TABLE registration.product_registration ADD CONSTRAINT fk_product_registration_product FOREIGN KEY(product_id) REFERENCES product.product(id) ON DELETE RESTRICT;

-- ============================================================================
-- MIGRATION: 000152_product_versions.sql
-- ============================================================================
CREATE TABLE product.product_version (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), dosage_form_code VARCHAR(100), shelf_life_value INTEGER CHECK(shelf_life_value IS NULL OR shelf_life_value>=0),
 shelf_life_unit VARCHAR(30), storage_conditions TEXT, indications TEXT, dosage_text TEXT, withdrawal_period TEXT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(product_id,version_no), CONSTRAINT ck_product_version_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE product.product_target_species (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id UUID NOT NULL REFERENCES product.product_version(id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, usage_notes TEXT, UNIQUE(product_version_id,species_id));
CREATE INDEX idx_product_version_product ON product.product_version(product_id,status);

-- ============================================================================
-- MIGRATION: 000153_product_composition.sql
-- ============================================================================
CREATE TABLE product.product_ingredient (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_version_id UUID NOT NULL REFERENCES product.product_version(id) ON DELETE RESTRICT,
 ingredient_id UUID NOT NULL REFERENCES product.ingredient(id) ON DELETE RESTRICT, ingredient_role VARCHAR(50), amount NUMERIC(18,6), unit_code VARCHAR(30), amount_basis TEXT,
 CONSTRAINT ck_product_ingredient_amount CHECK(amount IS NULL OR amount>=0));
CREATE INDEX idx_product_ingredient_version ON product.product_ingredient(product_version_id); CREATE INDEX idx_product_ingredient_ingredient ON product.product_ingredient(ingredient_id);

-- ============================================================================
-- MIGRATION: 000154_product_packages.sql
-- ============================================================================
CREATE TABLE product.package (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 package_code VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_package_code ON product.package(product_id,package_code) WHERE package_code IS NOT NULL;
CREATE TABLE product.package_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), package_id UUID NOT NULL REFERENCES product.package(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), pack_size NUMERIC(18,6), unit_code VARCHAR(30), container_type VARCHAR(100), pack_description TEXT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(package_id,version_no),
 CONSTRAINT ck_package_size CHECK(pack_size IS NULL OR pack_size>0), CONSTRAINT ck_package_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE INDEX idx_package_product ON product.package(product_id);

-- ============================================================================
-- MIGRATION: 000155_product_labels.sql
-- ============================================================================
CREATE TABLE product.label_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), package_version_id UUID NOT NULL REFERENCES product.package_version(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), language_code VARCHAR(10), document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(package_version_id,version_no,language_code),
 CONSTRAINT ck_label_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));

-- ============================================================================
-- MIGRATION: 000156_product_manufacturers.sql
-- ============================================================================
CREATE TABLE product.manufacturer_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 manufacturer_party_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT, manufacturing_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 responsibility_type VARCHAR(50) NOT NULL DEFAULT 'MANUFACTURER', valid_from DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_manufacturer_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_product_manufacturer_company ON product.manufacturer_assignment(manufacturer_party_id); CREATE INDEX idx_product_manufacturer_product ON product.manufacturer_assignment(product_id,status);

-- ============================================================================
-- MIGRATION: 000157_product_registration_packages.sql
-- ============================================================================
CREATE TABLE registration.product_registration_package (registration_id UUID NOT NULL REFERENCES registration.registration(id) ON DELETE RESTRICT,
 package_id UUID NOT NULL REFERENCES product.package(id) ON DELETE RESTRICT, registration_package_no VARCHAR(120), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 PRIMARY KEY(registration_id,package_id));
CREATE UNIQUE INDEX uq_registration_package_no ON registration.product_registration_package(registration_package_no) WHERE registration_package_no IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000158_product_batch.sql
-- ============================================================================
CREATE TABLE product.batch (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 product_version_id UUID REFERENCES product.product_version(id) ON DELETE RESTRICT, facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 batch_no VARCHAR(150) NOT NULL, manufacture_date DATE, expiry_date DATE, quantity NUMERIC(20,6), unit_code VARCHAR(30),
 release_status VARCHAR(30) NOT NULL DEFAULT 'PENDING', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(product_id,batch_no),
 CONSTRAINT ck_product_batch_dates CHECK(expiry_date IS NULL OR manufacture_date IS NULL OR expiry_date>=manufacture_date),
 CONSTRAINT ck_product_batch_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE INDEX idx_batch_product ON product.batch(product_id); CREATE INDEX idx_batch_number ON product.batch(batch_no);

-- ============================================================================
-- MIGRATION: 000170_feed_profile_formula.sql
-- ============================================================================
CREATE TABLE feed.feed_profile (product_id UUID PRIMARY KEY REFERENCES product.product(id) ON DELETE RESTRICT, feed_category VARCHAR(100), intended_use TEXT,
 production_stage VARCHAR(100), medicated_feed BOOLEAN NOT NULL DEFAULT FALSE);
CREATE TABLE feed.formula (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), product_id UUID NOT NULL REFERENCES product.product(id) ON DELETE RESTRICT,
 formula_code VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_feed_formula_code ON feed.formula(product_id,formula_code) WHERE formula_code IS NOT NULL;
CREATE TABLE feed.formula_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), formula_id UUID NOT NULL REFERENCES feed.formula(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from DATE, effective_to DATE, reason_for_change TEXT,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, source_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', UNIQUE(formula_id,version_no), CONSTRAINT ck_formula_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE feed.formula_ingredient (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), formula_version_id UUID NOT NULL REFERENCES feed.formula_version(id) ON DELETE RESTRICT,
 ingredient_id UUID NOT NULL REFERENCES product.ingredient(id) ON DELETE RESTRICT, inclusion_value NUMERIC(18,6), inclusion_unit VARCHAR(30), notes TEXT,
 CONSTRAINT ck_formula_inclusion CHECK(inclusion_value IS NULL OR inclusion_value>=0));
CREATE INDEX idx_formula_product ON feed.formula(product_id); CREATE INDEX idx_formula_ingredient_version ON feed.formula_ingredient(formula_version_id);

-- ============================================================================
-- MIGRATION: 000171_feed_raw_material_traceability.sql
-- ============================================================================
CREATE TABLE feed.raw_material_lot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
 material_name TEXT NOT NULL, supplier_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, supplier_lot_no VARCHAR(150), received_date DATE,
 quantity NUMERIC(20,6), unit_code VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE', CONSTRAINT ck_raw_material_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE TABLE feed.batch_material_usage (batch_id UUID NOT NULL REFERENCES product.batch(id) ON DELETE RESTRICT,
 raw_material_lot_id UUID NOT NULL REFERENCES feed.raw_material_lot(id) ON DELETE RESTRICT, quantity_used NUMERIC(20,6), unit_code VARCHAR(30),
 PRIMARY KEY(batch_id,raw_material_lot_id), CONSTRAINT ck_batch_material_qty CHECK(quantity_used IS NULL OR quantity_used>=0));
CREATE INDEX idx_raw_material_facility ON feed.raw_material_lot(facility_id,status);

-- ============================================================================
-- MIGRATION: 000200_inspection_program.sql
-- ============================================================================
CREATE TABLE inspection.program (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 domain_code VARCHAR(50) NOT NULL, inspection_type VARCHAR(50) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE inspection.program_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_id UUID NOT NULL REFERENCES inspection.program(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT,
 effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL, configuration JSONB, UNIQUE(program_id,version_no),
 CONSTRAINT ck_inspection_program_dates CHECK(effective_to IS NULL OR effective_to>effective_from));

-- ============================================================================
-- MIGRATION: 000201_inspection_checklist.sql
-- ============================================================================
CREATE TABLE inspection.checklist (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE inspection.checklist_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_id UUID NOT NULL REFERENCES inspection.checklist(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL,
 UNIQUE(checklist_id,version_no), CONSTRAINT ck_checklist_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE inspection.program_checklist (program_version_id UUID NOT NULL REFERENCES inspection.program_version(id) ON DELETE RESTRICT,
 checklist_version_id UUID NOT NULL REFERENCES inspection.checklist_version(id) ON DELETE RESTRICT, is_primary BOOLEAN NOT NULL DEFAULT TRUE,
 PRIMARY KEY(program_version_id,checklist_version_id));
CREATE TABLE inspection.checklist_item (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), checklist_version_id UUID NOT NULL REFERENCES inspection.checklist_version(id) ON DELETE CASCADE,
 parent_item_id UUID REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT, item_code VARCHAR(100) NOT NULL, item_type VARCHAR(30) NOT NULL,
 requirement_text_lo TEXT, requirement_text_en TEXT, response_type VARCHAR(30), is_required BOOLEAN NOT NULL DEFAULT FALSE,
 evidence_required BOOLEAN NOT NULL DEFAULT FALSE, scoring_rule JSONB, sequence_no INTEGER NOT NULL, UNIQUE(checklist_version_id,item_code));

-- ============================================================================
-- MIGRATION: 000202_inspection_runtime.sql
-- ============================================================================
CREATE TABLE inspection.inspection_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_no VARCHAR(120) NOT NULL UNIQUE,
 program_version_id UUID NOT NULL REFERENCES inspection.program_version(id) ON DELETE RESTRICT, facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, trigger_type VARCHAR(40) NOT NULL, priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
 status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', planned_date DATE, opened_at TIMESTAMPTZ NOT NULL DEFAULT now(), closed_at TIMESTAMPTZ,
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE inspection.visit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 visit_no INTEGER NOT NULL CHECK(visit_no>0), started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, location geography(Point,4326),
 offline_created BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED', UNIQUE(inspection_case_id,visit_no));
CREATE TABLE inspection.assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 inspector_user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, assignment_role VARCHAR(30) NOT NULL DEFAULT 'INSPECTOR',
 assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(), conflict_declared BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'ASSIGNED');
CREATE TABLE inspection.response (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 checklist_item_id UUID NOT NULL REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT, response_code VARCHAR(100), response_text TEXT, numeric_value NUMERIC(20,6),
 answered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, answered_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(visit_id,checklist_item_id));
CREATE INDEX idx_inspection_case_facility ON inspection.inspection_case(facility_id,status); CREATE INDEX idx_inspection_assignment_user ON inspection.assignment(inspector_user_id,status);
ALTER TABLE facility.gmp_assessment ADD CONSTRAINT fk_gmp_inspection_case FOREIGN KEY(inspection_case_id) REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT;

-- ============================================================================
-- MIGRATION: 000203_inspection_evidence_findings.sql
-- ============================================================================
CREATE TABLE inspection.evidence (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), visit_id UUID NOT NULL REFERENCES inspection.visit(id) ON DELETE RESTRICT,
 document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, evidence_type VARCHAR(40) NOT NULL, captured_at TIMESTAMPTZ,
 captured_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, location geography(Point,4326), sha256_checksum VARCHAR(64), notes TEXT);
CREATE TABLE inspection.finding (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 visit_id UUID REFERENCES inspection.visit(id) ON DELETE RESTRICT, checklist_item_id UUID REFERENCES inspection.checklist_item(id) ON DELETE RESTRICT,
 finding_no INTEGER NOT NULL CHECK(finding_no>0), severity_code VARCHAR(30), observation TEXT NOT NULL,
 regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', due_date DATE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(inspection_case_id,finding_no));
CREATE TABLE inspection.finding_evidence (finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 evidence_id UUID NOT NULL REFERENCES inspection.evidence(id) ON DELETE RESTRICT, PRIMARY KEY(finding_id,evidence_id));
CREATE INDEX idx_finding_case_status ON inspection.finding(inspection_case_id,status);

-- ============================================================================
-- MIGRATION: 000220_compliance.sql
-- ============================================================================
CREATE TABLE compliance.violation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 violation_code VARCHAR(100), regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, classification VARCHAR(30),
 confirmed_at TIMESTAMPTZ, confirmed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'UNDER_REVIEW');
CREATE TABLE compliance.capa (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), finding_id UUID NOT NULL REFERENCES inspection.finding(id) ON DELETE RESTRICT,
 responsible_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, due_date DATE, submitted_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE compliance.capa_action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), capa_id UUID NOT NULL REFERENCES compliance.capa(id) ON DELETE RESTRICT,
 action_no INTEGER NOT NULL CHECK(action_no>0), action_text TEXT NOT NULL, responsible_person_party_id UUID REFERENCES master.person(party_id) ON DELETE RESTRICT,
 target_date DATE, completion_date DATE, evidence_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
 UNIQUE(capa_id,action_no));
CREATE TABLE compliance.verification (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), capa_id UUID NOT NULL REFERENCES compliance.capa(id) ON DELETE RESTRICT,
 verification_type VARCHAR(30) NOT NULL, verified_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 result VARCHAR(30) NOT NULL, comments TEXT);
CREATE INDEX idx_capa_finding ON compliance.capa(finding_id,status); CREATE INDEX idx_capa_due ON compliance.capa(due_date) WHERE status NOT IN ('CLOSED','VERIFIED');

-- ============================================================================
-- MIGRATION: 000230_enforcement.sql
-- ============================================================================
CREATE TABLE enforcement.enforcement_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_no VARCHAR(120) NOT NULL UNIQUE,
 source_inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, regulated_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN', opened_at TIMESTAMPTZ NOT NULL DEFAULT now(), closed_at TIMESTAMPTZ);
CREATE TABLE enforcement.enforcement_case_violation (enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 violation_id UUID NOT NULL REFERENCES compliance.violation(id) ON DELETE RESTRICT, PRIMARY KEY(enforcement_case_id,violation_id));
CREATE TABLE enforcement.action (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 action_type VARCHAR(50) NOT NULL, decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, effective_from TIMESTAMPTZ, effective_to TIMESTAMPTZ,
 reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_enforcement_action_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));
CREATE TABLE enforcement.appeal (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), enforcement_case_id UUID NOT NULL REFERENCES enforcement.enforcement_case(id) ON DELETE RESTRICT,
 decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, appellant_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 submitted_at TIMESTAMPTZ NOT NULL, grounds TEXT, status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED', review_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT);
CREATE INDEX idx_enforcement_party ON enforcement.enforcement_case(regulated_party_id,status); CREATE INDEX idx_enforcement_facility ON enforcement.enforcement_case(facility_id,status);

-- ============================================================================
-- MIGRATION: 000240_laboratory_profile.sql
-- ============================================================================
CREATE TABLE laboratory.laboratory (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 laboratory_code VARCHAR(100) UNIQUE, laboratory_level VARCHAR(50), accreditation_status VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');

-- ============================================================================
-- MIGRATION: 000241_laboratory_sample_custody.sql
-- ============================================================================
CREATE TABLE laboratory.sample (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_no VARCHAR(120) NOT NULL UNIQUE, sample_type VARCHAR(100) NOT NULL,
 source_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
 disease_case_id UUID, animal_id UUID, animal_group_id UUID, collected_at TIMESTAMPTZ, collected_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 received_laboratory_id UUID REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT, received_at TIMESTAMPTZ,
 sample_status VARCHAR(30) NOT NULL DEFAULT 'COLLECTED', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE laboratory.sample_custody_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT,
 event_type VARCHAR(50) NOT NULL, from_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT, to_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 occurred_at TIMESTAMPTZ NOT NULL, temperature NUMERIC(8,3), condition_code VARCHAR(50), location geography(Point,4326),
 recorded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, notes TEXT);
CREATE INDEX idx_sample_lab_status ON laboratory.sample(received_laboratory_id,sample_status); CREATE INDEX idx_sample_inspection ON laboratory.sample(inspection_case_id);
CREATE INDEX idx_sample_custody_time ON laboratory.sample_custody_event(sample_id,occurred_at);

-- ============================================================================
-- MIGRATION: 000243_laboratory_test_method.sql
-- ============================================================================
CREATE TABLE laboratory.test_method (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), method_code VARCHAR(100) NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 name_lo TEXT, name_en TEXT NOT NULL, reference_standard TEXT, effective_from DATE, effective_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 UNIQUE(method_code,version_no), CONSTRAINT ck_test_method_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from));

-- ============================================================================
-- MIGRATION: 000244_laboratory_work_order.sql
-- ============================================================================
CREATE TABLE laboratory.test_request (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), request_no VARCHAR(120) NOT NULL UNIQUE,
 sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT, requested_by_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 priority VARCHAR(20) NOT NULL DEFAULT 'ROUTINE', requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED');
CREATE TABLE laboratory.work_order (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), test_request_id UUID NOT NULL REFERENCES laboratory.test_request(id) ON DELETE RESTRICT,
 method_id UUID NOT NULL REFERENCES laboratory.test_method(id) ON DELETE RESTRICT, assigned_analyst_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'QUEUED');
CREATE INDEX idx_work_order_analyst_status ON laboratory.work_order(assigned_analyst_id,status);

-- ============================================================================
-- MIGRATION: 000246_laboratory_result.sql
-- ============================================================================
CREATE TABLE laboratory.result (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), work_order_id UUID NOT NULL UNIQUE REFERENCES laboratory.work_order(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE laboratory.result_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), result_id UUID NOT NULL REFERENCES laboratory.result(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), result_code VARCHAR(100), result_text TEXT, numeric_value NUMERIC(20,8), unit_code VARCHAR(30), interpretation VARCHAR(100),
 entered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, entered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 validated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, validated_at TIMESTAMPTZ,
 approved_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, approved_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
 supersedes_version_id UUID REFERENCES laboratory.result_version(id) ON DELETE RESTRICT, UNIQUE(result_id,version_no));
CREATE INDEX idx_result_version_status ON laboratory.result_version(result_id,status,version_no DESC);

-- ============================================================================
-- MIGRATION: 000248_laboratory_equipment_quality.sql
-- ============================================================================
CREATE TABLE laboratory.equipment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), laboratory_id UUID NOT NULL REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT,
 equipment_code VARCHAR(100), name TEXT NOT NULL, serial_no VARCHAR(150), calibration_due_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_lab_equipment_code ON laboratory.equipment(laboratory_id,equipment_code) WHERE equipment_code IS NOT NULL;
CREATE TABLE laboratory.calibration (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), equipment_id UUID NOT NULL REFERENCES laboratory.equipment(id) ON DELETE RESTRICT,
 calibration_date DATE NOT NULL, next_due_date DATE, result VARCHAR(30), certificate_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
 CONSTRAINT ck_calibration_dates CHECK(next_due_date IS NULL OR next_due_date>=calibration_date));
CREATE TABLE laboratory.quality_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), laboratory_id UUID NOT NULL REFERENCES laboratory.laboratory(facility_id) ON DELETE RESTRICT,
 event_type VARCHAR(50) NOT NULL, event_date DATE NOT NULL, description TEXT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN');
CREATE INDEX idx_equipment_calibration_due ON laboratory.equipment(calibration_due_date) WHERE status='ACTIVE';

-- ============================================================================
-- MIGRATION: 000300_species_breed.sql
-- ============================================================================
CREATE TABLE lookup.breed (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT,
 code VARCHAR(100), name_lo TEXT, name_en TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE UNIQUE INDEX uq_breed_code ON lookup.breed(species_id,code) WHERE code IS NOT NULL;
CREATE INDEX idx_breed_species ON lookup.breed(species_id);

-- ============================================================================
-- MIGRATION: 000310_farm.sql
-- ============================================================================
CREATE TABLE farm.farm (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT, farm_code VARCHAR(120),
 production_system VARCHAR(100), commercial_scale VARCHAR(50), biosecurity_level VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_farm_code ON farm.farm(farm_code) WHERE farm_code IS NOT NULL;
CREATE TABLE farm.species_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, breed_id UUID REFERENCES lookup.breed(id) ON DELETE RESTRICT,
 production_type VARCHAR(100), valid_from DATE NOT NULL DEFAULT CURRENT_DATE, valid_to DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_farm_species_dates CHECK(valid_to IS NULL OR valid_to>=valid_from));
CREATE TABLE farm.population_snapshot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, snapshot_date DATE NOT NULL, total_count BIGINT NOT NULL CHECK(total_count>=0),
 male_count BIGINT CHECK(male_count IS NULL OR male_count>=0), female_count BIGINT CHECK(female_count IS NULL OR female_count>=0),
 young_count BIGINT CHECK(young_count IS NULL OR young_count>=0), source_type VARCHAR(50), created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE farm.biosecurity_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 assessment_date DATE NOT NULL, inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, score NUMERIC(10,4), classification VARCHAR(50), notes TEXT);
CREATE TABLE farm.production_cycle (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), farm_id UUID NOT NULL REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, cycle_no VARCHAR(120), start_date DATE, end_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_production_cycle_dates CHECK(end_date IS NULL OR start_date IS NULL OR end_date>=start_date));
CREATE INDEX idx_farm_species_farm ON farm.species_assignment(farm_id,status); CREATE INDEX idx_farm_population_date ON farm.population_snapshot(farm_id,species_id,snapshot_date DESC);

-- ============================================================================
-- MIGRATION: 000320_animal_identity.sql
-- ============================================================================
CREATE TABLE animal.animal (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_no VARCHAR(120), species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT,
 breed_id UUID REFERENCES lookup.breed(id) ON DELETE RESTRICT, sex_code VARCHAR(20), birth_date DATE, birth_date_estimated BOOLEAN NOT NULL DEFAULT FALSE,
 lifecycle_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_animal_no ON animal.animal(animal_no) WHERE animal_no IS NOT NULL;
CREATE TABLE animal.identifier (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 identifier_type VARCHAR(40) NOT NULL, identifier_value VARCHAR(150) NOT NULL, issued_at TIMESTAMPTZ, retired_at TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(identifier_type,identifier_value));
CREATE TABLE animal.animal_group (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), group_no VARCHAR(120) NOT NULL UNIQUE,
 species_id UUID NOT NULL REFERENCES lookup.species(id) ON DELETE RESTRICT, farm_id UUID REFERENCES farm.farm(facility_id) ON DELETE RESTRICT,
 production_batch_reference VARCHAR(150), initial_quantity BIGINT CHECK(initial_quantity IS NULL OR initial_quantity>=0),
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_animal_species ON animal.animal(species_id,lifecycle_status); CREATE INDEX idx_animal_group_farm ON animal.animal_group(farm_id,status);

-- ============================================================================
-- MIGRATION: 000323_animal_history.sql
-- ============================================================================
CREATE TABLE animal.ownership_history (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 owner_party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT, valid_from TIMESTAMPTZ NOT NULL, valid_to TIMESTAMPTZ, source_event_id UUID,
 CONSTRAINT ck_ownership_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE TABLE animal.location_history (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID NOT NULL REFERENCES animal.animal(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 valid_from TIMESTAMPTZ NOT NULL, valid_to TIMESTAMPTZ, source_type VARCHAR(50), source_id UUID,
 CONSTRAINT ck_location_dates CHECK(valid_to IS NULL OR valid_to>valid_from));
CREATE INDEX idx_ownership_current ON animal.ownership_history(animal_id,valid_to); CREATE INDEX idx_location_current ON animal.location_history(animal_id,valid_to);

-- ============================================================================
-- MIGRATION: 000330_movement.sql
-- ============================================================================
CREATE TABLE animal.movement (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_no VARCHAR(120) NOT NULL UNIQUE,
 source_case_id UUID REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, origin_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 destination_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, departure_at TIMESTAMPTZ, arrival_at TIMESTAMPTZ,
 purpose_code VARCHAR(50), status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_movement_times CHECK(arrival_at IS NULL OR departure_at IS NULL OR arrival_at>=departure_at));
CREATE TABLE animal.movement_subject (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 quantity BIGINT CHECK(quantity IS NULL OR quantity>=0), CONSTRAINT ck_movement_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE TABLE animal.movement_transport (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 vehicle_reference VARCHAR(150), driver_name TEXT, driver_contact VARCHAR(100), cleaning_confirmed BOOLEAN, disinfection_confirmed BOOLEAN);
CREATE TABLE animal.movement_checkpoint (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), movement_id UUID NOT NULL REFERENCES animal.movement(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, checked_at TIMESTAMPTZ, result_code VARCHAR(50),
 officer_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, notes TEXT);
CREATE INDEX idx_movement_origin ON animal.movement(origin_facility_id,departure_at); CREATE INDEX idx_movement_destination ON animal.movement(destination_facility_id,arrival_at);
CREATE INDEX idx_movement_subject_animal ON animal.movement_subject(animal_id) WHERE animal_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000340_animal_lifecycle_event.sql
-- ============================================================================
CREATE TABLE animal.lifecycle_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT,
 animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT, event_type VARCHAR(50) NOT NULL, occurred_at TIMESTAMPTZ NOT NULL,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, related_entity_type VARCHAR(100), related_entity_id UUID, details JSONB,
 recorded_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_lifecycle_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE INDEX idx_lifecycle_animal_time ON animal.lifecycle_event(animal_id,occurred_at DESC) WHERE animal_id IS NOT NULL;
CREATE INDEX idx_lifecycle_group_time ON animal.lifecycle_event(animal_group_id,occurred_at DESC) WHERE animal_group_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000400_disease_catalog.sql
-- ============================================================================
CREATE TABLE disease.disease (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 scientific_name TEXT, disease_category VARCHAR(100), zoonotic BOOLEAN NOT NULL DEFAULT FALSE, aquatic BOOLEAN NOT NULL DEFAULT FALSE,
 notifiable_status VARCHAR(50), is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TRIGGER trg_disease_updated_at BEFORE UPDATE ON disease.disease FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000401_surveillance.sql
-- ============================================================================
CREATE TABLE disease.surveillance_program (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_code VARCHAR(100) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, name_lo TEXT NOT NULL, name_en TEXT, surveillance_type VARCHAR(50) NOT NULL,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE disease.surveillance_program_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), program_id UUID NOT NULL REFERENCES disease.surveillance_program(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from DATE NOT NULL, effective_to DATE, sampling_strategy JSONB, target_population JSONB, reporting_rules JSONB,
 status VARCHAR(30) NOT NULL, UNIQUE(program_id,version_no), CONSTRAINT ck_surveillance_dates CHECK(effective_to IS NULL OR effective_to>=effective_from));
CREATE TABLE disease.surveillance_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), surveillance_no VARCHAR(120) NOT NULL UNIQUE,
 program_version_id UUID REFERENCES disease.surveillance_program_version(id) ON DELETE RESTRICT, disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT,
 facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 observed_at TIMESTAMPTZ NOT NULL, source_type VARCHAR(50) NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'REPORTED',
 created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_surveillance_disease_time ON disease.surveillance_event(disease_id,observed_at DESC); CREATE INDEX idx_surveillance_admin ON disease.surveillance_event(admin_unit_id,observed_at DESC);

-- ============================================================================
-- MIGRATION: 000410_disease_case_investigation.sql
-- ============================================================================
CREATE TABLE disease.disease_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), case_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, surveillance_event_id UUID REFERENCES disease.surveillance_event(id) ON DELETE RESTRICT,
 premises_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 case_classification VARCHAR(40) NOT NULL DEFAULT 'SUSPECTED', onset_date DATE, reported_at TIMESTAMPTZ NOT NULL DEFAULT now(), confirmed_at TIMESTAMPTZ,
 closed_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'OPEN');
CREATE TABLE disease.disease_case_subject (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 affected_quantity BIGINT CHECK(affected_quantity IS NULL OR affected_quantity>=0), morbidity_quantity BIGINT CHECK(morbidity_quantity IS NULL OR morbidity_quantity>=0),
 mortality_quantity BIGINT CHECK(mortality_quantity IS NULL OR mortality_quantity>=0),
 CONSTRAINT ck_disease_case_subject CHECK((animal_id IS NOT NULL AND animal_group_id IS NULL) OR (animal_id IS NULL AND animal_group_id IS NOT NULL)));
CREATE TABLE disease.investigation (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 investigation_no INTEGER NOT NULL CHECK(investigation_no>0), investigator_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, clinical_summary TEXT, epidemiological_summary TEXT, suspected_source TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'OPEN', UNIQUE(disease_case_id,investigation_no));
CREATE TABLE disease.epidemiological_link (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT,
 target_case_id UUID REFERENCES disease.disease_case(id) ON DELETE RESTRICT, movement_id UUID REFERENCES animal.movement(id) ON DELETE RESTRICT,
 link_type VARCHAR(50) NOT NULL, confidence_level VARCHAR(30), description TEXT, identified_at TIMESTAMPTZ NOT NULL DEFAULT now());
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_disease_case FOREIGN KEY(disease_case_id) REFERENCES disease.disease_case(id) ON DELETE RESTRICT;
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_animal FOREIGN KEY(animal_id) REFERENCES animal.animal(id) ON DELETE RESTRICT;
ALTER TABLE laboratory.sample ADD CONSTRAINT fk_lab_sample_animal_group FOREIGN KEY(animal_group_id) REFERENCES animal.animal_group(id) ON DELETE RESTRICT;
CREATE INDEX idx_disease_case_disease_status ON disease.disease_case(disease_id,status,reported_at DESC);

-- ============================================================================
-- MIGRATION: 000420_outbreak_zone_control.sql
-- ============================================================================
CREATE TABLE disease.outbreak (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID NOT NULL REFERENCES disease.disease(id) ON DELETE RESTRICT, confirmation_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 outbreak_start_date DATE, confirmation_date DATE, closure_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE disease.outbreak_case (outbreak_id UUID NOT NULL REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 disease_case_id UUID NOT NULL REFERENCES disease.disease_case(id) ON DELETE RESTRICT, PRIMARY KEY(outbreak_id,disease_case_id));
CREATE TABLE disease.zone (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_id UUID NOT NULL REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 zone_type VARCHAR(50) NOT NULL, zone_name TEXT, geometry geometry(MultiPolygon,4326), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_zone_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE TABLE disease.control_measure (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT,
 disease_case_id UUID REFERENCES disease.disease_case(id) ON DELETE RESTRICT, zone_id UUID REFERENCES disease.zone(id) ON DELETE RESTRICT, measure_type VARCHAR(50) NOT NULL,
 started_at TIMESTAMPTZ, ended_at TIMESTAMPTZ, authority_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE disease.movement_restriction (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT,
 outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT, zone_id UUID REFERENCES disease.zone(id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, restriction_type VARCHAR(50) NOT NULL, effective_from TIMESTAMPTZ NOT NULL,
 effective_to TIMESTAMPTZ, decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_restriction_dates CHECK(effective_to IS NULL OR effective_to>effective_from));
CREATE INDEX idx_zone_geometry ON disease.zone USING GIST(geometry); CREATE INDEX idx_active_restriction ON disease.movement_restriction(species_id,effective_from,effective_to) WHERE status='ACTIVE';

-- ============================================================================
-- MIGRATION: 000430_vaccination.sql
-- ============================================================================
CREATE TABLE disease.vaccination_campaign (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), campaign_no VARCHAR(120) NOT NULL UNIQUE,
 disease_id UUID REFERENCES disease.disease(id) ON DELETE RESTRICT, name_lo TEXT NOT NULL, name_en TEXT, start_date DATE, end_date DATE,
 target_definition JSONB, status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', CONSTRAINT ck_campaign_dates CHECK(end_date IS NULL OR start_date IS NULL OR end_date>=start_date));
CREATE TABLE disease.vaccination_event (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), campaign_id UUID REFERENCES disease.vaccination_campaign(id) ON DELETE RESTRICT,
 animal_id UUID REFERENCES animal.animal(id) ON DELETE RESTRICT, animal_group_id UUID REFERENCES animal.animal_group(id) ON DELETE RESTRICT,
 farm_id UUID REFERENCES farm.farm(facility_id) ON DELETE RESTRICT, vaccine_product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 product_batch_id UUID REFERENCES product.batch(id) ON DELETE RESTRICT, vaccinated_at TIMESTAMPTZ NOT NULL,
 vaccinated_quantity BIGINT CHECK(vaccinated_quantity IS NULL OR vaccinated_quantity>=0), administered_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
 CONSTRAINT ck_vaccination_subject CHECK(animal_id IS NOT NULL OR animal_group_id IS NOT NULL OR farm_id IS NOT NULL));
CREATE INDEX idx_vaccination_animal ON disease.vaccination_event(animal_id,vaccinated_at DESC) WHERE animal_id IS NOT NULL;
CREATE INDEX idx_vaccination_farm ON disease.vaccination_event(farm_id,vaccinated_at DESC) WHERE farm_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000440_emergency.sql
-- ============================================================================
CREATE TABLE disease.emergency_incident (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_no VARCHAR(120) NOT NULL UNIQUE,
 outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT, incident_level VARCHAR(30), activated_at TIMESTAMPTZ NOT NULL,
 deactivated_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_incident_dates CHECK(deactivated_at IS NULL OR deactivated_at>=activated_at));
CREATE TABLE disease.emergency_team_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID NOT NULL REFERENCES disease.emergency_incident(id) ON DELETE RESTRICT,
 user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, team_role VARCHAR(50) NOT NULL, assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(), released_at TIMESTAMPTZ);
CREATE TABLE disease.emergency_activity (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID NOT NULL REFERENCES disease.emergency_incident(id) ON DELETE RESTRICT,
 activity_type VARCHAR(50) NOT NULL, activity_at TIMESTAMPTZ NOT NULL, organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 summary TEXT, document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT);

-- ============================================================================
-- MIGRATION: 000450_amr.sql
-- ============================================================================
CREATE TABLE disease.amr_isolate (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), sample_id UUID NOT NULL REFERENCES laboratory.sample(id) ON DELETE RESTRICT,
 organism_code VARCHAR(100) NOT NULL, isolate_code VARCHAR(120), isolation_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX uq_amr_isolate_code ON disease.amr_isolate(isolate_code) WHERE isolate_code IS NOT NULL;
CREATE TABLE disease.amr_susceptibility (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), isolate_id UUID NOT NULL REFERENCES disease.amr_isolate(id) ON DELETE RESTRICT,
 antimicrobial_code VARCHAR(100) NOT NULL, test_method_id UUID REFERENCES laboratory.test_method(id) ON DELETE RESTRICT, numeric_value NUMERIC(20,8),
 unit_code VARCHAR(30), interpretation_code VARCHAR(30), result_version_id UUID REFERENCES laboratory.result_version(id) ON DELETE RESTRICT);
CREATE INDEX idx_amr_isolate_sample ON disease.amr_isolate(sample_id);

-- ============================================================================
-- MIGRATION: 000500_trade_operator_permit.sql
-- ============================================================================
CREATE TABLE trade.operator (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), party_id UUID NOT NULL REFERENCES master.party(id) ON DELETE RESTRICT,
 operator_no VARCHAR(120), operator_status VARCHAR(30) NOT NULL DEFAULT 'PENDING', registration_id UUID REFERENCES registration.registration(id) ON DELETE RESTRICT,
 valid_from DATE, valid_to DATE, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT ck_trade_operator_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE UNIQUE INDEX uq_trade_operator_no ON trade.operator(operator_no) WHERE operator_no IS NOT NULL; CREATE INDEX idx_trade_operator_party ON trade.operator(party_id,operator_status);
CREATE TABLE trade.permit_type (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT, is_active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE trade.permit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), permit_no VARCHAR(120) NOT NULL UNIQUE,
 permit_type_id UUID NOT NULL REFERENCES trade.permit_type(id) ON DELETE RESTRICT, operator_id UUID NOT NULL REFERENCES trade.operator(id) ON DELETE RESTRICT,
 source_case_id UUID NOT NULL REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT, decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 issue_date DATE NOT NULL, valid_from TIMESTAMPTZ, valid_to TIMESTAMPTZ, status VARCHAR(30) NOT NULL,
 CONSTRAINT ck_trade_permit_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from));
CREATE INDEX idx_trade_permit_operator ON trade.permit(operator_id,status);

-- ============================================================================
-- MIGRATION: 000510_shipment.sql
-- ============================================================================
CREATE TABLE trade.shipment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_no VARCHAR(120) NOT NULL UNIQUE,
 permit_id UUID REFERENCES trade.permit(id) ON DELETE RESTRICT, operator_id UUID NOT NULL REFERENCES trade.operator(id) ON DELETE RESTRICT,
 origin_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, destination_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT,
 entry_exit_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT, expected_arrival_at TIMESTAMPTZ, actual_arrival_at TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL DEFAULT 'DECLARED', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE trade.shipment_item (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 line_no INTEGER NOT NULL CHECK(line_no>0), commodity_class VARCHAR(50) NOT NULL, product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 species_id UUID REFERENCES lookup.species(id) ON DELETE RESTRICT, description TEXT, quantity NUMERIC(20,6), unit_code VARCHAR(30),
 country_of_origin_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, UNIQUE(shipment_id,line_no), CONSTRAINT ck_shipment_item_qty CHECK(quantity IS NULL OR quantity>=0));
CREATE TABLE trade.shipment_transport (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 mode_code VARCHAR(30), vehicle_or_vessel_reference VARCHAR(150), container_reference VARCHAR(150), carrier_name TEXT, seal_number VARCHAR(100));
CREATE INDEX idx_shipment_operator_status ON trade.shipment(operator_id,status,expected_arrival_at); CREATE INDEX idx_shipment_item_product ON trade.shipment_item(product_id) WHERE product_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000513_border_declaration.sql
-- ============================================================================
CREATE TABLE trade.border_declaration (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 declaration_no VARCHAR(120), declaration_type VARCHAR(30) NOT NULL DEFAULT 'PRE_ARRIVAL', submitted_at TIMESTAMPTZ,
 external_customs_reference VARCHAR(200), status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED');
CREATE UNIQUE INDEX uq_border_declaration_no ON trade.border_declaration(declaration_no) WHERE declaration_no IS NOT NULL;
CREATE INDEX idx_border_declaration_shipment ON trade.border_declaration(shipment_id,submitted_at DESC);

-- ============================================================================
-- MIGRATION: 000520_trade_risk.sql
-- ============================================================================
CREATE TABLE trade.risk_assessment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 risk_model_version VARCHAR(100) NOT NULL, assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(), risk_score NUMERIC(10,4), risk_band VARCHAR(30),
 required_control VARCHAR(50), explanation JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE INDEX idx_trade_risk_shipment ON trade.risk_assessment(shipment_id,assessed_at DESC);

-- ============================================================================
-- MIGRATION: 000521_border_inspection.sql
-- ============================================================================
CREATE TABLE trade.border_inspection (shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 inspection_case_id UUID NOT NULL REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT, PRIMARY KEY(shipment_id,inspection_case_id));

-- ============================================================================
-- MIGRATION: 000522_quarantine_clearance.sql
-- ============================================================================
CREATE TABLE trade.quarantine_case (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), quarantine_no VARCHAR(120) NOT NULL UNIQUE,
 shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT, quarantine_facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ NOT NULL, released_at TIMESTAMPTZ, release_decision_id UUID REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_quarantine_dates CHECK(released_at IS NULL OR released_at>=started_at));
CREATE TABLE trade.clearance_decision (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT,
 decision_id UUID NOT NULL REFERENCES casework.regulatory_decision(id) ON DELETE RESTRICT, clearance_type VARCHAR(50) NOT NULL, decided_at TIMESTAMPTZ NOT NULL, conditions TEXT);
CREATE INDEX idx_quarantine_shipment ON trade.quarantine_case(shipment_id,status); CREATE INDEX idx_clearance_shipment ON trade.clearance_decision(shipment_id,decided_at DESC);

-- ============================================================================
-- MIGRATION: 000530_trade_health_certificate.sql
-- ============================================================================
CREATE TABLE trade.health_certificate (certificate_id UUID PRIMARY KEY REFERENCES document.certificate(id) ON DELETE RESTRICT,
 shipment_id UUID NOT NULL REFERENCES trade.shipment(id) ON DELETE RESTRICT, certificate_profile_code VARCHAR(100),
 destination_country_id UUID REFERENCES lookup.country(id) ON DELETE RESTRICT, structured_payload JSONB NOT NULL);
CREATE INDEX idx_health_certificate_shipment ON trade.health_certificate(shipment_id);

-- ============================================================================
-- MIGRATION: 000531_ecertificate.sql
-- ============================================================================
CREATE TABLE trade.ecertificate_message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), certificate_id UUID NOT NULL REFERENCES document.certificate(id) ON DELETE RESTRICT,
 partner_system_id UUID, message_direction VARCHAR(10) NOT NULL CHECK(message_direction IN ('INBOUND','OUTBOUND')), message_standard VARCHAR(50), schema_version VARCHAR(50),
 external_message_id VARCHAR(200), payload JSONB, sent_received_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'PENDING');
CREATE UNIQUE INDEX uq_ecert_external_message ON trade.ecertificate_message(external_message_id) WHERE external_message_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000550_aquaculture.sql
-- ============================================================================
CREATE TABLE fisheries.aquaculture_facility (facility_id UUID PRIMARY KEY REFERENCES master.facility(id) ON DELETE RESTRICT,
 production_system VARCHAR(100), water_source_type VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE fisheries.aquaculture_unit (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES fisheries.aquaculture_facility(facility_id) ON DELETE RESTRICT,
 unit_code VARCHAR(100), unit_type VARCHAR(50) NOT NULL, capacity_value NUMERIC(20,6), capacity_unit VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 CONSTRAINT ck_aquaculture_capacity CHECK(capacity_value IS NULL OR capacity_value>=0));
CREATE UNIQUE INDEX uq_aquaculture_unit_code ON fisheries.aquaculture_unit(facility_id,unit_code) WHERE unit_code IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000552_aquatic_stock_production.sql
-- ============================================================================
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

-- ============================================================================
-- MIGRATION: 000600_integration_registry.sql
-- ============================================================================
CREATE TABLE integration.system (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_code VARCHAR(100) NOT NULL UNIQUE, name TEXT NOT NULL,
 owner_organization TEXT, integration_type VARCHAR(50), environment VARCHAR(30), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE integration.endpoint (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_id UUID NOT NULL REFERENCES integration.system(id) ON DELETE RESTRICT,
 endpoint_code VARCHAR(100) NOT NULL, endpoint_type VARCHAR(30) NOT NULL, base_url TEXT, authentication_type VARCHAR(50), credential_reference TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(system_id,endpoint_code));
CREATE TABLE integration.mapping (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_id UUID NOT NULL REFERENCES integration.system(id) ON DELETE RESTRICT,
 mapping_code VARCHAR(100) NOT NULL, mapping_version INTEGER NOT NULL DEFAULT 1 CHECK(mapping_version>0), source_schema TEXT, target_schema TEXT,
 mapping_config JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(system_id,mapping_code,mapping_version));
ALTER TABLE trade.ecertificate_message ADD CONSTRAINT fk_ecert_partner_system FOREIGN KEY(partner_system_id) REFERENCES integration.system(id) ON DELETE RESTRICT;

-- ============================================================================
-- MIGRATION: 000610_notifications.sql
-- ============================================================================
CREATE TABLE notification.template (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), template_code VARCHAR(100) NOT NULL, language_code VARCHAR(10) NOT NULL,
 channel VARCHAR(30) NOT NULL, subject_template TEXT, body_template TEXT NOT NULL, version_no INTEGER NOT NULL CHECK(version_no>0),
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(template_code,language_code,channel,version_no));
CREATE TABLE notification.message (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_type VARCHAR(150), recipient_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
 recipient_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, template_id UUID REFERENCES notification.template(id) ON DELETE RESTRICT,
 payload JSONB, status VARCHAR(30) NOT NULL DEFAULT 'QUEUED', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_notification_recipient CHECK(recipient_party_id IS NOT NULL OR recipient_user_id IS NOT NULL));
CREATE TABLE notification.delivery (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), message_id UUID NOT NULL REFERENCES notification.message(id) ON DELETE RESTRICT,
 channel VARCHAR(30) NOT NULL, destination_masked TEXT, provider_reference TEXT, attempt_no INTEGER NOT NULL DEFAULT 1 CHECK(attempt_no>0),
 attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(), delivered_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL, error_text TEXT);
CREATE INDEX idx_notification_queue ON notification.message(created_at) WHERE status='QUEUED';

-- ============================================================================
-- MIGRATION: 000620_gis_layer_registry.sql
-- ============================================================================
CREATE TABLE gis.layer (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), layer_code VARCHAR(100) NOT NULL UNIQUE, name_lo TEXT NOT NULL, name_en TEXT,
 source_domain VARCHAR(50), geometry_type VARCHAR(50), is_public BOOLEAN NOT NULL DEFAULT FALSE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE gis.layer_version (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), layer_id UUID NOT NULL REFERENCES gis.layer(id) ON DELETE RESTRICT,
 version_no INTEGER NOT NULL CHECK(version_no>0), effective_from TIMESTAMPTZ NOT NULL, effective_to TIMESTAMPTZ, configuration JSONB,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE(layer_id,version_no), CONSTRAINT ck_gis_layer_dates CHECK(effective_to IS NULL OR effective_to>effective_from));

-- ============================================================================
-- MIGRATION: 000630_analytics_kpi.sql
-- ============================================================================
CREATE TABLE analytics.kpi_definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), kpi_code VARCHAR(100) NOT NULL UNIQUE, domain_code VARCHAR(50) NOT NULL,
 name_lo TEXT NOT NULL, name_en TEXT, calculation_version INTEGER NOT NULL DEFAULT 1 CHECK(calculation_version>0), unit_code VARCHAR(30), definition TEXT,
 configuration JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE analytics.metric_snapshot (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), kpi_id UUID NOT NULL REFERENCES analytics.kpi_definition(id) ON DELETE RESTRICT,
 period_start TIMESTAMPTZ NOT NULL, period_end TIMESTAMPTZ NOT NULL, admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
 organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT, numeric_value NUMERIC(30,8), calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CONSTRAINT ck_metric_period CHECK(period_end>=period_start));
CREATE TABLE analytics.dashboard_definition (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dashboard_code VARCHAR(100) NOT NULL UNIQUE,
 name_lo TEXT NOT NULL, name_en TEXT, audience_code VARCHAR(50), configuration JSONB, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE INDEX idx_metric_kpi_period ON analytics.metric_snapshot(kpi_id,period_start,period_end);

-- ============================================================================
-- MIGRATION: 000640_scheduler.sql
-- ============================================================================
CREATE TABLE system.scheduled_job (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), job_code VARCHAR(100) NOT NULL UNIQUE, job_type VARCHAR(50) NOT NULL,
 schedule_expression TEXT, configuration JSONB, is_enabled BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE system.scheduled_job_execution (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), job_id UUID NOT NULL REFERENCES system.scheduled_job(id) ON DELETE RESTRICT,
 started_at TIMESTAMPTZ NOT NULL, finished_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL, error_text TEXT, metrics JSONB);
CREATE INDEX idx_job_execution_time ON system.scheduled_job_execution(job_id,started_at DESC);

-- ============================================================================
-- MIGRATION: 000650_data_quality.sql
-- ============================================================================
CREATE TABLE system.data_quality_issue (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, entity_id UUID,
 issue_type VARCHAR(100) NOT NULL, severity VARCHAR(30), description TEXT, status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
 detected_at TIMESTAMPTZ NOT NULL DEFAULT now(), resolved_at TIMESTAMPTZ);
CREATE TABLE system.data_merge_request (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, source_entity_id UUID NOT NULL,
 target_entity_id UUID NOT NULL, requested_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 reviewed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, reviewed_at TIMESTAMPTZ, decision VARCHAR(30), reason TEXT, status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
 CONSTRAINT ck_merge_distinct CHECK(source_entity_id<>target_entity_id));
CREATE INDEX idx_data_quality_open ON system.data_quality_issue(entity_type,issue_type,detected_at) WHERE status='OPEN';

-- ============================================================================
-- MIGRATION: 000660_retention_archive.sql
-- ============================================================================
CREATE TABLE system.retention_policy (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), data_category VARCHAR(100) NOT NULL, classification VARCHAR(30),
 retention_years INTEGER CHECK(retention_years IS NULL OR retention_years>=0), archive_required BOOLEAN NOT NULL DEFAULT FALSE,
 disposal_allowed BOOLEAN NOT NULL DEFAULT FALSE, regulatory_rule_id UUID REFERENCES system.regulatory_rule(id) ON DELETE RESTRICT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE system.archive_record (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), entity_type VARCHAR(100) NOT NULL, entity_id UUID NOT NULL,
 retention_policy_id UUID REFERENCES system.retention_policy(id) ON DELETE RESTRICT, archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 archived_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT, archive_reference TEXT, checksum VARCHAR(64));
CREATE INDEX idx_archive_entity ON system.archive_record(entity_type,entity_id);

-- ============================================================================
-- MIGRATION: 000670_reporting_views.sql
-- ============================================================================
CREATE OR REPLACE VIEW analytics.v_active_licenses AS
SELECT id,license_no,license_type_id,holder_party_id,issue_date,effective_from,expiry_date,status FROM licensing.license WHERE status IN ('ACTIVE','VALID','ISSUED');
CREATE OR REPLACE VIEW analytics.v_active_registrations AS
SELECT id,registration_no,registration_type_id,holder_party_id,issue_date,effective_from,expiry_date,status FROM registration.registration WHERE status IN ('ACTIVE','VALID','ISSUED');
CREATE OR REPLACE VIEW analytics.v_open_inspection_findings AS
SELECT f.id,f.inspection_case_id,f.finding_no,f.severity_code,f.status,f.due_date,c.facility_id FROM inspection.finding f JOIN inspection.inspection_case c ON c.id=f.inspection_case_id WHERE f.status NOT IN ('CLOSED','RESOLVED');
CREATE OR REPLACE VIEW analytics.v_current_outbreaks AS
SELECT id,outbreak_no,disease_id,outbreak_start_date,confirmation_date,status FROM disease.outbreak WHERE status='ACTIVE';

-- ============================================================================
-- MIGRATION: 000680_final_indexes.sql
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_party_role_active ON master.party_role_assignment(party_id,role_type_id,valid_to) WHERE status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_facility_type_active ON master.facility_type_assignment(facility_id,facility_type_id,valid_to) WHERE status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_case_workflow ON casework.regulatory_case(workflow_instance_id) WHERE workflow_instance_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_certificate_verify ON document.certificate(verification_token) WHERE verification_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inspection_visit_location ON inspection.visit USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_inspection_evidence_location ON inspection.evidence USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_sample_source_facility ON laboratory.sample(source_facility_id,collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_movement_status_departure ON animal.movement(status,departure_at);
CREATE INDEX IF NOT EXISTS idx_disease_case_admin ON disease.disease_case(admin_unit_id,reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_outbreak_disease_status ON disease.outbreak(disease_id,status,confirmation_date DESC);
CREATE INDEX IF NOT EXISTS idx_trade_shipment_arrival ON trade.shipment(entry_exit_facility_id,expected_arrival_at,status);
CREATE INDEX IF NOT EXISTS idx_trade_item_class ON trade.shipment_item(commodity_class);
CREATE INDEX IF NOT EXISTS idx_aquaculture_stock_species ON fisheries.stock_batch(species_id,status);

-- Database guardrails for official/audit history. Business correction uses linked new records, not hard delete.
CREATE TRIGGER trg_no_delete_regulatory_decision BEFORE DELETE ON casework.regulatory_decision
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_registration BEFORE DELETE ON registration.registration
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_license BEFORE DELETE ON licensing.license
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_certificate BEFORE DELETE ON document.certificate
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_audit_event BEFORE DELETE ON audit.event
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_inspection_evidence BEFORE DELETE ON inspection.evidence
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_lab_result_version BEFORE DELETE ON laboratory.result_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_approved_lab_result_immutable BEFORE UPDATE ON laboratory.result_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('APPROVED');
CREATE TRIGGER trg_no_delete_animal_lifecycle BEFORE DELETE ON animal.lifecycle_event
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_outbreak BEFORE DELETE ON disease.outbreak
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_trade_permit BEFORE DELETE ON trade.permit
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_trade_shipment BEFORE DELETE ON trade.shipment
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

-- ============================================================================
-- MIGRATION: 000700_priority_veterinary_products_trade.sql
-- ============================================================================
-- LVSP Priority Veterinary Products Pack v0.4.0
-- Operational records for veterinary drug registration, veterinary devices,
-- annual import plans, and mixed-item import applications.

CREATE TABLE IF NOT EXISTS product.product_regulatory_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL UNIQUE REFERENCES product.product(id) ON DELETE RESTRICT,
  registration_no VARCHAR(120) UNIQUE,
  registration_type VARCHAR(40) NOT NULL DEFAULT 'IMPORT',
  trade_name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  dosage_form TEXT,
  registration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  application_no VARCHAR(120),
  application_date DATE,
  dlf_no VARCHAR(120),
  dlf_date DATE,
  issue_date DATE,
  expiry_date DATE,
  holder_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  importer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  target_species TEXT,
  active_ingredients TEXT,
  route TEXT,
  contraindications TEXT,
  warnings TEXT,
  gmp_reference TEXT,
  cpp_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_product_reg_profile_dates CHECK(expiry_date IS NULL OR issue_date IS NULL OR expiry_date >= issue_date)
);
CREATE INDEX IF NOT EXISTS idx_product_reg_profile_status ON product.product_regulatory_profile(registration_status,expiry_date);
CREATE INDEX IF NOT EXISTS idx_product_reg_profile_holder ON product.product_regulatory_profile(holder_company_id);
CREATE TRIGGER trg_product_regulatory_profile_updated_at BEFORE UPDATE ON product.product_regulatory_profile FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS product.veterinary_device (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_code VARCHAR(120) UNIQUE,
  device_name TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  device_category TEXT,
  intended_use TEXT,
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  importer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  registration_no VARCHAR(120),
  authorization_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  technical_specification TEXT,
  serial_tracking BOOLEAN NOT NULL DEFAULT FALSE,
  shelf_life TEXT,
  storage_conditions TEXT,
  instructions_for_use TEXT,
  certificate_references TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_veterinary_device_status ON product.veterinary_device(authorization_status);
CREATE INDEX IF NOT EXISTS idx_veterinary_device_importer ON product.veterinary_device(importer_company_id);
CREATE TRIGGER trg_veterinary_device_updated_at BEFORE UPDATE ON product.veterinary_device FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_no VARCHAR(120) NOT NULL UNIQUE,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  plan_year INTEGER NOT NULL CHECK(plan_year BETWEEN 2000 AND 2200),
  application_date DATE,
  approval_no VARCHAR(120),
  approval_date DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_plan_company_year ON trade.import_plan(company_id,plan_year,status);
CREATE TRIGGER trg_import_plan_updated_at BEFORE UPDATE ON trade.import_plan FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_plan_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES trade.import_plan(id) ON DELETE CASCADE,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_type VARCHAR(40) NOT NULL CHECK(item_type IN ('MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT')),
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  planned_quantity NUMERIC(18,3) NOT NULL DEFAULT 0 CHECK(planned_quantity >= 0),
  unit_code VARCHAR(40),
  planned_value NUMERIC(18,2) CHECK(planned_value IS NULL OR planned_value >= 0),
  currency_code VARCHAR(10) DEFAULT 'USD',
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id,item_no),
  CONSTRAINT ck_import_plan_item_ref CHECK (NOT (product_id IS NOT NULL AND device_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_plan ON trade.import_plan_item(plan_id,item_type);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_product ON trade.import_plan_item(product_id) WHERE product_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS trade.import_application (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_no VARCHAR(120) NOT NULL UNIQUE,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  plan_id UUID REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  application_date DATE NOT NULL DEFAULT current_date,
  import_type VARCHAR(30) NOT NULL DEFAULT 'IMPORT',
  border_checkpoint TEXT,
  invoice_no VARCHAR(120),
  invoice_date DATE,
  origin_country TEXT,
  transport_information TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  decision_no VARCHAR(120),
  decision_date DATE,
  permit_no VARCHAR(120),
  permit_valid_to DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_application_company ON trade.import_application(company_id,status,application_date);
CREATE INDEX IF NOT EXISTS idx_import_application_plan ON trade.import_application(plan_id) WHERE plan_id IS NOT NULL;
CREATE TRIGGER trg_import_application_updated_at BEFORE UPDATE ON trade.import_application FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS trade.import_application_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES trade.import_application(id) ON DELETE CASCADE,
  plan_item_id UUID REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_type VARCHAR(40) NOT NULL CHECK(item_type IN ('MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT')),
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  requested_quantity NUMERIC(18,3) NOT NULL DEFAULT 0 CHECK(requested_quantity >= 0),
  approved_quantity NUMERIC(18,3) CHECK(approved_quantity IS NULL OR approved_quantity >= 0),
  cleared_quantity NUMERIC(18,3) CHECK(cleared_quantity IS NULL OR cleared_quantity >= 0),
  unit_code VARCHAR(40),
  item_value NUMERIC(18,2) CHECK(item_value IS NULL OR item_value >= 0),
  currency_code VARCHAR(10) DEFAULT 'USD',
  eligibility_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  eligibility_message TEXT,
  antimicrobial BOOLEAN NOT NULL DEFAULT FALSE,
  active_substance_kg NUMERIC(18,6) CHECK(active_substance_kg IS NULL OR active_substance_kg >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(application_id,item_no),
  CONSTRAINT ck_import_application_item_ref CHECK (NOT (product_id IS NOT NULL AND device_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_import_app_item_application ON trade.import_application_item(application_id,item_type);
CREATE INDEX IF NOT EXISTS idx_import_app_item_product ON trade.import_application_item(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_import_app_item_device ON trade.import_application_item(device_id) WHERE device_id IS NOT NULL;

-- ============================================================================
-- MIGRATION: 000710_priority_veterinary_products_complete.sql
-- ============================================================================
-- LVSP v0.5.0 Priority Veterinary Products Complete
-- Completes detailed drug registry + multi-presentation model and bulk import support.

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS dosage_group TEXT,
  ADD COLUMN IF NOT EXISTS atcvet TEXT,
  ADD COLUMN IF NOT EXISTS distribution_classification TEXT,
  ADD COLUMN IF NOT EXISTS shelf_life TEXT,
  ADD COLUMN IF NOT EXISTS storage_conditions TEXT,
  ADD COLUMN IF NOT EXISTS indications TEXT,
  ADD COLUMN IF NOT EXISTS dosage_administration TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_meat TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_milk TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_eggs TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_honey TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_aquatic TEXT,
  ADD COLUMN IF NOT EXISTS applicant_name TEXT,
  ADD COLUMN IF NOT EXISTS applicant_nationality TEXT,
  ADD COLUMN IF NOT EXISTS applicant_id_no TEXT,
  ADD COLUMN IF NOT EXISTS business_license_no TEXT,
  ADD COLUMN IF NOT EXISTS business_license_date DATE,
  ADD COLUMN IF NOT EXISTS manufacturer_address TEXT,
  ADD COLUMN IF NOT EXISTS distributor_name TEXT,
  ADD COLUMN IF NOT EXISTS distributor_country TEXT,
  ADD COLUMN IF NOT EXISTS distributor_address TEXT,
  ADD COLUMN IF NOT EXISTS origin_registration_no TEXT,
  ADD COLUMN IF NOT EXISTS origin_registration_date DATE,
  ADD COLUMN IF NOT EXISTS valid_years INTEGER;

ALTER TABLE product.package
  ADD COLUMN IF NOT EXISTS sub_code VARCHAR(30),
  ADD COLUMN IF NOT EXISTS presentation_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE';
CREATE UNIQUE INDEX IF NOT EXISTS uq_package_sub_code ON product.package(product_id,sub_code) WHERE sub_code IS NOT NULL;

ALTER TABLE product.package_version
  ADD COLUMN IF NOT EXISTS strength_text TEXT,
  ADD COLUMN IF NOT EXISTS basis_text TEXT,
  ADD COLUMN IF NOT EXISTS target_text TEXT,
  ADD COLUMN IF NOT EXISTS total_weight_text TEXT,
  ADD COLUMN IF NOT EXISTS is_kit BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS product.package_composition (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_version_id UUID NOT NULL REFERENCES product.package_version(id) ON DELETE CASCADE,
  sequence_no INTEGER NOT NULL DEFAULT 1 CHECK(sequence_no > 0),
  ingredient_name TEXT NOT NULL,
  ingredient_role VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
  quantity_text TEXT,
  unit_text TEXT,
  part_text TEXT,
  equivalence_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(package_version_id, sequence_no)
);
CREATE INDEX IF NOT EXISTS idx_package_composition_version ON product.package_composition(package_version_id);

-- Original source row / import trace helps audit bulk spreadsheet uploads.
ALTER TABLE trade.import_plan_item
  ADD COLUMN IF NOT EXISTS package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS source_file_name TEXT,
  ADD COLUMN IF NOT EXISTS source_row_no INTEGER,
  ADD COLUMN IF NOT EXISTS source_payload JSONB,
  ADD COLUMN IF NOT EXISTS validation_status VARCHAR(30) DEFAULT 'VALID',
  ADD COLUMN IF NOT EXISTS validation_message TEXT;
ALTER TABLE trade.import_application_item
  ADD COLUMN IF NOT EXISTS package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS batch_lot_no TEXT,
  ADD COLUMN IF NOT EXISTS manufacture_date DATE,
  ADD COLUMN IF NOT EXISTS expiry_date DATE,
  ADD COLUMN IF NOT EXISTS source_file_name TEXT,
  ADD COLUMN IF NOT EXISTS source_row_no INTEGER,
  ADD COLUMN IF NOT EXISTS source_payload JSONB,
  ADD COLUMN IF NOT EXISTS validation_status VARCHAR(30) DEFAULT 'VALID',
  ADD COLUMN IF NOT EXISTS validation_message TEXT;

-- ============================================================================
-- MIGRATION: 000720_legacy_trade_print_animuse.sql
-- ============================================================================
-- LVSP v0.6.0 — legacy trade migration, print support, AMR/ANIMUSE reference
ALTER TABLE trade.import_application
  ADD COLUMN IF NOT EXISTS legacy_source_id TEXT,
  ADD COLUMN IF NOT EXISTS legacy_source TEXT,
  ADD COLUMN IF NOT EXISTS signed_by TEXT,
  ADD COLUMN IF NOT EXISTS purpose TEXT,
  ADD COLUMN IF NOT EXISTS valid_from DATE,
  ADD COLUMN IF NOT EXISTS cleared_date DATE,
  ADD COLUMN IF NOT EXISTS destination_country TEXT,
  ADD COLUMN IF NOT EXISTS checkpoint_out TEXT,
  ADD COLUMN IF NOT EXISTS transport_mode TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_application_legacy_source_id ON trade.import_application(legacy_source_id) WHERE legacy_source_id IS NOT NULL;

ALTER TABLE trade.import_application_item
  ADD COLUMN IF NOT EXISTS legacy_source_id TEXT,
  ADD COLUMN IF NOT EXISTS legacy_kind TEXT,
  ADD COLUMN IF NOT EXISTS sub_code TEXT,
  ADD COLUMN IF NOT EXISTS gross_weight_kg NUMERIC(18,6),
  ADD COLUMN IF NOT EXISTS cleared_packs NUMERIC(18,3),
  ADD COLUMN IF NOT EXISTS amr_use TEXT,
  ADD COLUMN IF NOT EXISTS amr_group TEXT,
  ADD COLUMN IF NOT EXISTS amr_route TEXT,
  ADD COLUMN IF NOT EXISTS kg_override JSONB;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_application_item_legacy_source_id ON trade.import_application_item(legacy_source_id) WHERE legacy_source_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS analytics.amr_substance_reference (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  substance_key TEXT NOT NULL UNIQUE,
  substance_name_en TEXT NOT NULL,
  animuse_class_code TEXT,
  iu_per_mg NUMERIC,
  ionophore BOOLEAN NOT NULL DEFAULT FALSE,
  source TEXT,
  legacy_source_id TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_amr_substance_class ON analytics.amr_substance_reference(animuse_class_code);

CREATE OR REPLACE VIEW analytics.v_import_item_summary AS
SELECT
  ia.id AS application_id,
  ia.application_no,
  ia.application_date,
  ia.permit_no,
  ia.status,
  c.legal_name_lo AS company_name_lo,
  c.legal_name_en AS company_name_en,
  iai.item_type,
  COUNT(*) AS item_count,
  COALESCE(SUM(iai.requested_quantity),0) AS requested_quantity,
  COALESCE(SUM(iai.cleared_quantity),0) AS cleared_quantity,
  COALESCE(SUM(iai.item_value),0) AS value_usd,
  COALESCE(SUM(iai.gross_weight_kg),0) AS gross_weight_kg
FROM trade.import_application ia
JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_application_item iai ON iai.application_id=ia.id
GROUP BY ia.id, ia.application_no, ia.application_date, ia.permit_no, ia.status, c.legal_name_lo, c.legal_name_en, iai.item_type;

-- ============================================================================
-- MIGRATION: 000730_company_master_multisite.sql
-- ============================================================================
-- LVSP v0.8.0 — Company Master + Multi-Site / Multi-Address
-- Non-destructive normalization: one legal company -> many physical sites/addresses.

CREATE TABLE IF NOT EXISTS lookup.company_site_role (
  code VARCHAR(60) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
INSERT INTO lookup.company_site_role(code,name_lo,name_en,is_active) VALUES
('REGISTERED_OFFICE','ທີ່ຢູ່ຈົດທະບຽນ','Registered office',TRUE),
('HEAD_OFFICE','ສຳນັກງານໃຫຍ່','Head office',TRUE),
('BUSINESS_SITE','ສະຖານທີ່ດຳເນີນທຸລະກິດ','Business site',TRUE),
('BRANCH_OFFICE','ສາຂາ','Branch office',TRUE),
('REGISTRATION_HOLDER_OFFICE','ສຳນັກງານຜູ້ຖືທະບຽນ','Registration holder office',TRUE),
('IMPORTER_OFFICE','ສຳນັກງານຜູ້ນຳເຂົ້າ','Importer office',TRUE),
('MANUFACTURING_SITE','ໂຮງງານ/ສະຖານທີ່ຜະລິດ','Manufacturing site',TRUE),
('WAREHOUSE','ສາງ','Warehouse',TRUE),
('DISTRIBUTION_SITE','ສະຖານທີ່ຈັດຈຳໜ່າຍ','Distribution site',TRUE),
('OTHER','ສະຖານທີ່ອື່ນ','Other site',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO lookup.facility_type(code,name_lo,name_en,is_active) VALUES
('REGISTERED_OFFICE','ສຳນັກງານຈົດທະບຽນ','Registered Office',TRUE),
('HEAD_OFFICE','ສຳນັກງານໃຫຍ່','Head Office',TRUE),
('BUSINESS_SITE','ສະຖານທີ່ດຳເນີນທຸລະກິດ','Business Site',TRUE),
('BRANCH_OFFICE','ສຳນັກງານສາຂາ','Branch Office',TRUE),
('REGISTRATION_HOLDER_OFFICE','ສຳນັກງານຜູ້ຖືທະບຽນ','Registration Holder Office',TRUE),
('IMPORTER_OFFICE','ສຳນັກງານຜູ້ນຳເຂົ້າ','Importer Office',TRUE),
('MANUFACTURING_SITE','ໂຮງງານ/ສະຖານທີ່ຜະລິດ','Manufacturing Site',TRUE),
('DISTRIBUTION_SITE','ສະຖານທີ່ຈັດຈຳໜ່າຍ','Distribution Site',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;


INSERT INTO master.party_role_type(code,name_lo,name_en,allowed_party_kind,is_active) VALUES
('REGISTRATION_HOLDER','ຜູ້ຖືທະບຽນ','Registration Holder','COMPANY',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,allowed_party_kind=EXCLUDED.allowed_party_kind,is_active=TRUE;

ALTER TABLE master.company ADD COLUMN IF NOT EXISTS website TEXT;

CREATE TABLE IF NOT EXISTS master.company_alias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  alias_name TEXT NOT NULL,
  alias_type VARCHAR(40) NOT NULL DEFAULT 'LEGACY_NAME',
  source_system VARCHAR(80),
  valid_from DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(company_id,alias_name)
);
CREATE INDEX IF NOT EXISTS idx_company_alias_name_trgm ON master.company_alias USING GIN(alias_name gin_trgm_ops);

CREATE TABLE IF NOT EXISTS master.company_site (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
  site_role_code VARCHAR(60) NOT NULL REFERENCES lookup.company_site_role(code) ON DELETE RESTRICT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  notes TEXT,
  source_system VARCHAR(80),
  source_record_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_company_site_dates CHECK(valid_to IS NULL OR valid_to>=valid_from),
  UNIQUE(company_id,facility_id,site_role_code)
);
CREATE INDEX IF NOT EXISTS idx_company_site_company ON master.company_site(company_id,status);
CREATE INDEX IF NOT EXISTS idx_company_site_facility ON master.company_site(facility_id,status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_company_site_primary_role ON master.company_site(company_id,site_role_code) WHERE is_primary=TRUE AND status='ACTIVE';
CREATE TRIGGER trg_company_site_updated_at BEFORE UPDATE ON master.company_site FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS master.facility_contact (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES master.facility(id) ON DELETE RESTRICT,
  contact_type VARCHAR(30) NOT NULL CHECK(contact_type IN ('PHONE','EMAIL','WEBSITE','FAX','OTHER')),
  contact_value TEXT NOT NULL,
  label TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_facility_contact_dates CHECK(valid_to IS NULL OR valid_to>=valid_from)
);
CREATE INDEX IF NOT EXISTS idx_facility_contact_facility ON master.facility_contact(facility_id,status);

CREATE TABLE IF NOT EXISTS master.company_external_registration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  registration_type VARCHAR(60) NOT NULL,
  registration_no VARCHAR(150) NOT NULL,
  facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  issuing_authority TEXT,
  issue_date DATE,
  expiry_date DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  notes TEXT,
  source_system VARCHAR(80),
  source_record_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(company_id,registration_type,registration_no)
);
CREATE INDEX IF NOT EXISTS idx_company_external_registration ON master.company_external_registration(company_id,status,expiry_date);
CREATE TRIGGER trg_company_extreg_updated_at BEFORE UPDATE ON master.company_external_registration FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS holder_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS importer_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS manufacturer_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS manufacturer_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS distributor_company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS distributor_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS holder_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS holder_address_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS importer_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS importer_address_snapshot TEXT;

-- The master links are live/current. Snapshot columns preserve the regulatory text as it was at approval/issuance.
-- Issued certificates must not silently change because a company later moves or changes its current contact details.

ALTER TABLE trade.import_plan ADD COLUMN IF NOT EXISTS company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;
ALTER TABLE trade.import_application ADD COLUMN IF NOT EXISTS company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;

-- Keep old records valid. No automatic merge of possibly duplicate legal entities is performed.

-- ============================================================================
-- MIGRATION: 000740_guided_services_workflow.sql
-- ============================================================================
-- LVSP v0.9.0 — Guided Digital Services + Workflow UX foundation
-- Purpose: turn the enterprise architecture into configuration-driven, step-by-step services.
-- Regulatory requirements below are a staging baseline and remain subject to official legal/domain verification.

CREATE TABLE IF NOT EXISTS system.service_guide (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL UNIQUE REFERENCES system.service_version(id) ON DELETE RESTRICT,
  category_code VARCHAR(60),
  icon VARCHAR(20),
  display_order INTEGER NOT NULL DEFAULT 100,
  overview_lo TEXT,
  overview_en TEXT,
  eligibility_lo TEXT,
  eligibility_en TEXT,
  preparation_lo TEXT,
  preparation_en TEXT,
  processing_lo TEXT,
  processing_en TEXT,
  launch_module_key VARCHAR(100),
  launch_action VARCHAR(40) NOT NULL DEFAULT 'CREATE',
  allow_public_browse BOOLEAN NOT NULL DEFAULT TRUE,
  requires_authentication BOOLEAN NOT NULL DEFAULT TRUE,
  configuration_notice_lo TEXT,
  configuration_notice_en TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'PILOT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_service_guide_order ON system.service_guide(status,display_order);
DROP TRIGGER IF EXISTS trg_service_guide_updated_at ON system.service_guide;
CREATE TRIGGER trg_service_guide_updated_at BEFORE UPDATE ON system.service_guide FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_step (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  step_code VARCHAR(80) NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no>0),
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  step_type VARCHAR(40) NOT NULL DEFAULT 'GUIDANCE',
  actor_scope VARCHAR(30) NOT NULL DEFAULT 'APPLICANT',
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,step_code),
  UNIQUE(service_version_id,sequence_no)
);
CREATE INDEX IF NOT EXISTS idx_service_step_version ON system.service_step(service_version_id,sequence_no);
DROP TRIGGER IF EXISTS trg_service_step_updated_at ON system.service_step;
CREATE TRIGGER trg_service_step_updated_at BEFORE UPDATE ON system.service_step FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_requirement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  requirement_code VARCHAR(100) NOT NULL,
  requirement_type VARCHAR(30) NOT NULL DEFAULT 'DOCUMENT',
  sequence_no INTEGER NOT NULL DEFAULT 100,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  condition_configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
  example_note_lo TEXT,
  example_note_en TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,requirement_code)
);
CREATE INDEX IF NOT EXISTS idx_service_requirement_version ON system.service_requirement(service_version_id,sequence_no);
DROP TRIGGER IF EXISTS trg_service_requirement_updated_at ON system.service_requirement;
CREATE TRIGGER trg_service_requirement_updated_at BEFORE UPDATE ON system.service_requirement FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS system.service_output (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  output_code VARCHAR(100) NOT NULL,
  output_type VARCHAR(50) NOT NULL,
  sequence_no INTEGER NOT NULL DEFAULT 100,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  description_lo TEXT,
  description_en TEXT,
  template_code VARCHAR(100),
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(service_version_id,output_code)
);
CREATE INDEX IF NOT EXISTS idx_service_output_version ON system.service_output(service_version_id,sequence_no);

CREATE TABLE IF NOT EXISTS casework.service_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_version_id UUID NOT NULL REFERENCES system.service_version(id) ON DELETE RESTRICT,
  service_code_snapshot VARCHAR(50) NOT NULL,
  applicant_party_id UUID REFERENCES master.party(id) ON DELETE RESTRICT,
  company_id UUID REFERENCES master.company(party_id) ON DELETE RESTRICT,
  started_by_subject TEXT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'IN_PROGRESS',
  current_step_code VARCHAR(80),
  target_resource VARCHAR(100),
  target_id UUID,
  draft_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_service_draft_subject ON casework.service_draft(started_by_subject,status,updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_draft_company ON casework.service_draft(company_id,status) WHERE company_id IS NOT NULL;
DROP TRIGGER IF EXISTS trg_service_draft_updated_at ON casework.service_draft;
CREATE TRIGGER trg_service_draft_updated_at BEFORE UPDATE ON casework.service_draft FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE IF NOT EXISTS casework.service_draft_step (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id UUID NOT NULL REFERENCES casework.service_draft(id) ON DELETE CASCADE,
  step_code VARCHAR(80) NOT NULL,
  sequence_no INTEGER NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'NOT_STARTED',
  step_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(draft_id,step_code)
);
CREATE INDEX IF NOT EXISTS idx_service_draft_step ON casework.service_draft_step(draft_id,sequence_no);

CREATE TABLE IF NOT EXISTS casework.service_draft_requirement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id UUID NOT NULL REFERENCES casework.service_draft(id) ON DELETE CASCADE,
  requirement_id UUID NOT NULL REFERENCES system.service_requirement(id) ON DELETE RESTRICT,
  status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  note TEXT,
  document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  checked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(draft_id,requirement_id)
);
CREATE INDEX IF NOT EXISTS idx_service_draft_requirement ON casework.service_draft_requirement(draft_id,status);

-- Priority services used by the v0.9 guided portal.
INSERT INTO system.service_definition(service_code,domain_code,name_lo,name_en,description,applicant_type,is_public,is_active) VALUES
('TR-1021','TR','ແຜນນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດປະຈຳປີ','Annual Veterinary Products Import Plan','Annual plan covering medicines, vaccines, biologicals and veterinary devices in one plan.','COMPANY',TRUE,TRUE),
('TR-1007','TR','ຄຳຮ້ອງນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Products Import Application','One import application may contain mixed veterinary medicines, vaccines, biologicals and veterinary devices.','COMPANY',TRUE,TRUE)
ON CONFLICT(service_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description=EXCLUDED.description,applicant_type=EXCLUDED.applicant_type,is_public=TRUE,is_active=TRUE;

UPDATE system.service_definition SET applicant_type='COMPANY',is_public=TRUE,is_active=TRUE WHERE service_code='VM-1003';

INSERT INTO system.service_version(service_id,version_no,effective_from,workflow_code,status)
SELECT id,1,now(),CASE WHEN service_code='VM-1003' THEN 'WF-003' ELSE 'WF-006' END,'DRAFT'
FROM system.service_definition WHERE service_code IN ('VM-1003','TR-1021','TR-1007')
ON CONFLICT(service_id,version_no) DO NOTHING;

-- Guide headers. These are operational guidance baselines, not a claim that every requirement is legally mandatory in every case.
WITH v AS (
  SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd
  JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
  WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
  SELECT * FROM (VALUES
  ('VM-1003','REGISTRATION','💊',10,
   'ຄູ່ມືຂຶ້ນທະບຽນຢາສັດຕະວະແພດແບບທີລະຂັ້ນ. ລະບົບຈະພາກວດຂໍ້ມູນບໍລິສັດ, ຜະລິດຕະພັນ, ໂຮງງານ, ຂະໜາດບັນຈຸ, ເອກະສານ ແລະ ການທົບທວນກ່ອນຍື່ນ.',
   'Step-by-step veterinary product registration guide covering company, product, manufacturing site, package presentations, supporting dossier and review before submission.',
   'ກ່ອນເລີ່ມ ໃຫ້ກວດວ່າບໍລິສັດ, ຜູ້ຖືທະບຽນ, ຜູ້ນຳເຂົ້າ ແລະ ໂຮງງານ/ສະຖານທີ່ຜະລິດ ຖືກສ້າງໃນ Company Master ແລ້ວ.',
   'Before starting, confirm that the relevant legal companies and their offices/manufacturing sites exist in Company Master.',
   'ກະກຽມຂໍ້ມູນຜະລິດຕະພັນ, ສູດ/ສ່ວນປະກອບ, ສະຫຼາກ/ໃບແນະນຳ, ຂໍ້ມູນຄຸນນະພາບ ແລະ ຫຼັກຖານ GMP/CPP ຕາມກໍລະນີທີ່ນຳໃຊ້.',
   'Prepare product information, composition, labeling/leaflet, quality information and GMP/CPP evidence where applicable.',
   'ຫຼັງຍື່ນ ຄຳຮ້ອງຈະເຂົ້າຂັ້ນກວດຄວາມຄົບຖ້ວນ, ກວດວິຊາການ, ຕັດສິນ ແລະ ອອກເອກະສານຕາມ workflow ທີ່ປະກາດໃຊ້.',
   'After submission, the case moves through admissibility, technical review, decision and document issuance according to the published workflow.',
   'drug_registrations'),
  ('TR-1021','TRADE','📅',20,
   'ສ້າງແຜນນຳເຂົ້າປະຈຳປີ 1 ແຜນ ທີ່ຮອງຮັບຢາ, ວັກຊີນ, ຊີວະພັນ ແລະ ອຸປະກອນສັດຕະວະແພດນຳກັນ. ລາຍການຈຳນວນຫຼາຍສາມາດນຳເຂົ້າຈາກ Excel.',
   'Create one annual plan that may contain medicines, vaccines, biologicals and veterinary devices together, with Excel bulk import for large item lists.',
   'ກວດ Company Master ແລະ ສະຖານທີ່ຂອງຜູ້ປະກອບການກ່ອນ.',
   'Confirm the operator legal company and submitting office/site first.',
   'ກະກຽມປີແຜນ, ລາຍການສິນຄ້າ, ທະບຽນ/ຂະໜາດບັນຈຸທີ່ກ່ຽວຂ້ອງ, ຈຳນວນ, ຫົວໜ່ວຍ ແລະ ມູນຄ່າຖ້າມີ.',
   'Prepare plan year, items, relevant registration/package reference, quantities, units and values when available.',
   'ລະບົບຈະກວດລາຍການ ແລະ ຮັກສາແຜນເປັນຖານອ້າງອີງສຳລັບຄຳຮ້ອງນຳເຂົ້າແຕ່ລະຄັ້ງ.',
   'The approved/accepted plan becomes a reference for subsequent import applications as configured.',
   'import_plans'),
  ('TR-1007','TRADE','🚚',30,
   'ຄຳຮ້ອງນຳເຂົ້າ 1 ໃບສາມາດມີຢາ ແລະ ອຸປະກອນສັດຕະວະແພດນຳກັນ. ລະບົບຈະຊ່ວຍກວດການຂຶ້ນທະບຽນ, ຂະໜາດບັນຈຸ, ແຜນປະຈຳປີ ແລະ AMR/ANIMUSE ຕາມຂໍ້ມູນທີ່ມີ.',
   'One import application may contain mixed veterinary medicines and devices. LVSP guides registration/package, annual-plan and AMR/ANIMUSE checks using available data.',
   'ກ່ອນຍື່ນ ກວດ Company/Site, ແຜນປະຈຳປີທີ່ກ່ຽວຂ້ອງ ແລະ ຂໍ້ມູນສິນຄ້າ.',
   'Before submission, confirm Company/Site, the relevant annual plan and item master data.',
   'ກະກຽມ Invoice, ປະເທດຕົ້ນທາງ, ດ່ານ, ຈຸດປະສົງ ແລະ ລາຍການສິນຄ້າ. ສາມາດໃຊ້ Excel ເມື່ອມີຫຼາຍລາຍການ.',
   'Prepare invoice, origin, checkpoint, purpose and item details. Use Excel bulk import for large applications.',
   'ຫຼັງຍື່ນ ຕິດຕາມສະຖານະຈາກຮັບຄຳຮ້ອງ → ກວດ → ອະນຸມັດ/ອອກໃບ → ຜ່ານດ່ານ → ປິດແຟ້ມ ຕາມ workflow ທີ່ກຳນົດ.',
   'Track the case from receipt through review, authorization/document issuance, border processing and closure according to the configured workflow.',
   'import_applications')
  ) AS t(service_code,category_code,icon,display_order,overview_lo,overview_en,eligibility_lo,eligibility_en,preparation_lo,preparation_en,processing_lo,processing_en,launch_module_key)
)
INSERT INTO system.service_guide(service_version_id,category_code,icon,display_order,overview_lo,overview_en,eligibility_lo,eligibility_en,preparation_lo,preparation_en,processing_lo,processing_en,launch_module_key,configuration_notice_lo,configuration_notice_en,status)
SELECT v.service_version_id,x.category_code,x.icon,x.display_order,x.overview_lo,x.overview_en,x.eligibility_lo,x.eligibility_en,x.preparation_lo,x.preparation_en,x.processing_lo,x.processing_en,x.launch_module_key,
'ຂໍ້ກຳນົດ/ເອກະສານໃນໜ້ານີ້ແມ່ນ configuration ສຳລັບ Staging/Pilot. ກ່ອນ Production ຕ້ອງກວດຢືນຢັນກັບນິຕິກຳ ແລະ SOP ທາງການ.',
'Requirements shown here are staging/pilot configuration and must be verified against official legal instruments and SOPs before production.','PILOT'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id) DO UPDATE SET category_code=EXCLUDED.category_code,icon=EXCLUDED.icon,display_order=EXCLUDED.display_order,overview_lo=EXCLUDED.overview_lo,overview_en=EXCLUDED.overview_en,eligibility_lo=EXCLUDED.eligibility_lo,eligibility_en=EXCLUDED.eligibility_en,preparation_lo=EXCLUDED.preparation_lo,preparation_en=EXCLUDED.preparation_en,processing_lo=EXCLUDED.processing_lo,processing_en=EXCLUDED.processing_en,launch_module_key=EXCLUDED.launch_module_key,configuration_notice_lo=EXCLUDED.configuration_notice_lo,configuration_notice_en=EXCLUDED.configuration_notice_en,status='PILOT';

-- Steps are intentionally operational and configurable. They do not hard-code approval authority or legal time limits.
WITH v AS (
  SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
  WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company Master, ບົດບາດຜູ້ຖືທະບຽນ/ຜູ້ນຳເຂົ້າ ແລະ ໂຮງງານ/ສະຖານທີ່.','Confirm legal companies, roles and physical sites before entering the product.','GUIDANCE','APPLICANT','{}'),
 ('VM-1003','PRODUCT_CORE',20,'ຂໍ້ມູນຜະລິດຕະພັນ','Product core','ປ້ອນ Trade name, generic/INN, category, dosage form, target species, route, indications, dosage, shelf life ແລະ storage.','Enter product identity and clinical/quality summary fields.','FORM','APPLICANT','{"section":"product"}'),
 ('VM-1003','PARTIES_SITES',30,'ບໍລິສັດ ແລະ ສະຖານທີ່','Companies and sites','ເລືອກ Registration Holder, Importer, Manufacturer, Distributor ແລະ site ທີ່ຖືກຕ້ອງ.','Select each legal company and the correct role-specific site.','FORM','APPLICANT','{"section":"parties"}'),
 ('VM-1003','PRESENTATIONS',40,'ຂະໜາດບັນຈຸ ແລະ ສ່ວນປະກອບ','Package presentations and composition','ເພີ່ມທຸກ presentation. 1 product ສາມາດມີຫຼາຍຂະໜາດ ແລະຮັກສາ composition ຕາມ presentation.','Add all presentations and presentation-level composition.','FORM','APPLICANT','{"section":"presentations"}'),
 ('VM-1003','DOSSIER',50,'ເອກະສານປະກອບ','Supporting dossier','ກວດ checklist ຂອງເອກະສານທີ່ກຳນົດໄວ້ສຳລັບ service version ນີ້.','Review the configured supporting-document checklist.','DOCUMENTS','APPLICANT','{}'),
 ('VM-1003','REVIEW',60,'ກວດຄືນກ່ອນຍື່ນ','Review before submission','ກວດຊື່, ສູດ, package, company/site ແລະເອກະສານໃຫ້ຄົບ.','Review product, packages, parties/sites and documents.','REVIEW','APPLICANT','{}'),
 ('VM-1003','SUBMIT',70,'ຢືນຢັນ ແລະ ຍື່ນ','Declare and submit','ຢືນຢັນຄວາມຖືກຕ້ອງ ແລະສົ່ງເຂົ້າ workflow.','Confirm accuracy and submit into the configured workflow.','DECLARATION','APPLICANT','{}'),
 ('VM-1003','PROCESSING',80,'ຕິດຕາມການດຳເນີນ','Track processing','ຕິດຕາມການກວດຄວາມຄົບຖ້ວນ, ກວດວິຊາການ, ການຕັດສິນ ແລະ ອອກເອກະສານ.','Track admissibility, technical review, decision and document issuance.','TRACKING','SYSTEM','{}'),

 ('TR-1021','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company Master ແລະ site ທີ່ຈະໃຊ້ຍື່ນແຜນ.','Confirm the company and submitting site.','GUIDANCE','APPLICANT','{}'),
 ('TR-1021','PLAN_HEADER',20,'ຂໍ້ມູນແຜນ','Plan header','ກຳນົດປີ, ບໍລິສັດ, site, ວັນທີຍື່ນ ແລະເລກອ້າງອີງຕາມທີ່ລະບົບກຳນົດ.','Set plan year, company, site, application date and reference fields.','FORM','APPLICANT','{"section":"plan_header"}'),
 ('TR-1021','ITEMS',30,'ເພີ່ມລາຍການ','Add items','ປ້ອນລາຍການເອງ ຫຼື Import Excel. ຢາ ແລະ ອຸປະກອນສາມາດຢູ່ໃນແຜນດຽວ.','Enter items manually or import Excel; medicines and devices may be in the same plan.','ITEMS','APPLICANT','{"bulk_excel":true,"template":"Annual_Import_Plan_Template.xlsx"}'),
 ('TR-1021','VALIDATE',40,'ກວດລາຍການ','Validate items','ລະບົບກວດ item type, registration/package link ແລະ validation message ຕາມຂໍ້ມູນທີ່ມີ.','Validate item types and available registration/package references.','SYSTEM_CHECK','SYSTEM','{}'),
 ('TR-1021','REVIEW',50,'ກວດຄືນແຜນ','Review plan','ກວດຈຳນວນລາຍການ, ປະລິມານ, ຫົວໜ່ວຍ ແລະມູນຄ່າກ່ອນຍື່ນ.','Review item count, quantities, units and values before submission.','REVIEW','APPLICANT','{}'),
 ('TR-1021','SUBMIT',60,'ຍື່ນແຜນ','Submit plan','ບັນທຶກ/ຍື່ນແຜນເຂົ້າລະບົບຕາມ workflow ທີ່ກຳນົດ.','Save/submit the plan according to configured workflow.','DECLARATION','APPLICANT','{}'),

 ('TR-1007','BEFORE_START',10,'ກວດຄວາມພ້ອມ','Before you start','ກວດ Company/Site, ແຜນປະຈຳປີ ແລະລາຍການ product/device master.','Confirm company/site, relevant annual plan and product/device master records.','GUIDANCE','APPLICANT','{}'),
 ('TR-1007','APPLICATION_HEADER',20,'ຂໍ້ມູນຄຳຮ້ອງ','Application header','ປ້ອນວັນທີ, company/site, plan, invoice, origin, checkpoint ແລະ purpose.','Enter application date, company/site, plan, invoice, origin, checkpoint and purpose.','FORM','APPLICANT','{"section":"import_header"}'),
 ('TR-1007','ITEMS',30,'ລາຍການນຳເຂົ້າ','Import items','ເພີ່ມລາຍການເອງ ຫຼື Import Excel. 1 ຄຳຮ້ອງສາມາດມີ mixed items.','Enter items manually or by Excel; one application may contain mixed items.','ITEMS','APPLICANT','{"bulk_excel":true,"template":"Import_Application_Items_Template.xlsx"}'),
 ('TR-1007','SYSTEM_CHECKS',40,'ກວດອັດຕະໂນມັດ','System checks','ກວດ registration status, package, annual plan reference ແລະ AMR/ANIMUSE fields ເທົ່າທີ່ຂໍ້ມູນຮອງຮັບ.','Check registration, package, annual-plan reference and AMR/ANIMUSE fields where data supports it.','SYSTEM_CHECK','SYSTEM','{}'),
 ('TR-1007','DOCUMENTS',50,'ເອກະສານປະກອບ','Supporting documents','ກວດ checklist ເອກະສານຕາມ service configuration.','Review the configured supporting-document checklist.','DOCUMENTS','APPLICANT','{}'),
 ('TR-1007','REVIEW',60,'ກວດຄືນ','Review','Preview ຄຳຮ້ອງ ແລະລາຍການທັງໝົດກ່ອນຍື່ນ.','Preview the full application and items before submission.','REVIEW','APPLICANT','{}'),
 ('TR-1007','SUBMIT',70,'ຢືນຢັນ ແລະ ຍື່ນ','Declare and submit','ຢືນຢັນ ແລະສົ່ງຄຳຮ້ອງເຂົ້າ workflow.','Confirm and submit the application into workflow.','DECLARATION','APPLICANT','{}'),
 ('TR-1007','PROCESSING',80,'ຕິດຕາມສະຖານະ','Track processing','ຕິດຕາມຮັບຄຳຮ້ອງ, ກວດ, ອະນຸມັດ/ອອກໃບ, ຜ່ານດ່ານ ແລະປິດແຟ້ມຕາມ workflow.','Track receipt, review, authorization/document issuance, border processing and closure.','TRACKING','SYSTEM','{}')
 ) AS t(service_code,step_code,sequence_no,name_lo,name_en,description_lo,description_en,step_type,actor_scope,configuration_json)
)
INSERT INTO system.service_step(service_version_id,step_code,sequence_no,name_lo,name_en,description_lo,description_en,step_type,actor_scope,configuration,status)
SELECT v.service_version_id,x.step_code,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,x.step_type,x.actor_scope,x.configuration_json::jsonb,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,step_code) DO UPDATE SET sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,step_type=EXCLUDED.step_type,actor_scope=EXCLUDED.actor_scope,configuration=EXCLUDED.configuration,status='ACTIVE';

WITH v AS (
 SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
 WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','COMPANY_MASTER','PRECONDITION',10,'ບໍລິສັດ ແລະ Site/Facility ຖືກສ້າງແລ້ວ','Company and relevant sites exist','ກວດຂໍ້ມູນ Legal Company ແລະ role-specific office/factory site ກ່ອນ.','Confirm legal company and role-specific office/factory sites first.',TRUE),
 ('VM-1003','PRODUCT_INFO','DATA',20,'ຂໍ້ມູນຜະລິດຕະພັນ','Product information','Trade/generic name, dosage form, target species, composition, use, shelf life, storage and related data.','Product identity, composition, use, shelf life, storage and related data.',TRUE),
 ('VM-1003','GMP_EVIDENCE','DOCUMENT',30,'ຫຼັກຖານ GMP/ຄຸນນະພາບສະຖານທີ່ຜະລິດ','GMP/manufacturing-quality evidence','ນຳໃຊ້ຕາມກໍລະນີ ແລະ configuration ທາງການ.','Use where applicable under official configuration.',TRUE),
 ('VM-1003','CPP_OR_ORIGIN_STATUS','DOCUMENT',40,'CPP/ຫຼັກຖານສະຖານະໃນປະເທດຕົ້ນກຳເນີດ','CPP/origin-country status evidence','ນຳໃຊ້ຕາມກໍລະນີ.','Use where applicable.',FALSE),
 ('VM-1003','LABEL_LEAFLET','DOCUMENT',50,'ສະຫຼາກ ແລະ ໃບແນະນຳ','Label and leaflet','ສະບັບທີ່ຈະສະເໜີຂໍອະນຸມັດ.','Proposed approval versions.',TRUE),
 ('VM-1003','QUALITY_SPEC','DOCUMENT',60,'Specification/Stability/Quality information','Specification/Stability/Quality information','ເອກະສານຄຸນນະພາບຕາມກໍລະນີ.','Quality information where applicable.',FALSE),

 ('TR-1021','COMPANY_SITE','PRECONDITION',10,'Company/Site ຜູ້ຍື່ນແຜນ','Submitting company/site','ເລືອກຈາກ Company Master.','Select from Company Master.',TRUE),
 ('TR-1021','PLAN_ITEMS','DATA',20,'ລາຍການແຜນ','Plan item list','ລາຍການ, ປະລິມານ, ຫົວໜ່ວຍ, ຂະໜາດບັນຈຸ/ທະບຽນທີ່ກ່ຽວຂ້ອງ.','Items, quantities, units and relevant package/registration references.',TRUE),

 ('TR-1007','COMPANY_SITE','PRECONDITION',10,'Company/Site ຜູ້ຍື່ນ','Submitting company/site','ເລືອກຈາກ Company Master.','Select from Company Master.',TRUE),
 ('TR-1007','ANNUAL_PLAN','PRECONDITION',20,'ແຜນປະຈຳປີທີ່ກ່ຽວຂ້ອງ','Relevant annual plan','ໃຊ້ຕາມ workflow/rule configuration ທີ່ປະກາດໃຊ້.','Use according to the published workflow/rule configuration.',FALSE),
 ('TR-1007','INVOICE','DOCUMENT',30,'Invoice','Invoice','ຂໍ້ມູນ Invoice ແລະໄຟລ໌ປະກອບຖ້າກຳນົດ.','Invoice data and supporting file when configured.',TRUE),
 ('TR-1007','ITEM_LIST','DATA',40,'ລາຍການນຳເຂົ້າ','Import item list','ຮອງຮັບຢາ/ວັກຊີນ/ຊີວະພັນ/ອຸປະກອນໃນຄຳຮ້ອງດຽວ.','Supports mixed medicines/vaccines/biologicals/devices in one application.',TRUE),
 ('TR-1007','OTHER_CONFIGURED_DOCS','DOCUMENT',50,'ເອກະສານອື່ນຕາມການກຳນົດ','Other configured supporting documents','ລາຍການນີ້ຕ້ອງອີງ service/rule configuration ທາງການ.','This list must follow official service/rule configuration.',FALSE)
 ) AS t(service_code,requirement_code,requirement_type,sequence_no,name_lo,name_en,description_lo,description_en,is_required)
)
INSERT INTO system.service_requirement(service_version_id,requirement_code,requirement_type,sequence_no,name_lo,name_en,description_lo,description_en,is_required,status)
SELECT v.service_version_id,x.requirement_code,x.requirement_type,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,x.is_required,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,requirement_code) DO UPDATE SET requirement_type=EXCLUDED.requirement_type,sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,is_required=EXCLUDED.is_required,status='ACTIVE';

WITH v AS (
 SELECT sd.service_code,sv.id service_version_id FROM system.service_definition sd JOIN system.service_version sv ON sv.service_id=sd.id AND sv.version_no=1
 WHERE sd.service_code IN ('VM-1003','TR-1021','TR-1007')
), x AS (
 SELECT * FROM (VALUES
 ('VM-1003','REGISTRATION_RECORD','REGISTRATION',10,'ບັນທຶກ/ຜົນການຂຶ້ນທະບຽນ','Registration record/result','ຜົນອອກຕາມການຕັດສິນ ແລະ template ທາງການ.','Output according to regulatory decision and official template.'),
 ('VM-1003','REGISTRATION_CERTIFICATE','CERTIFICATE',20,'ໃບທະບຽນ','Registration certificate','1 presentation/ຂະໜາດບັນຈຸສາມາດອອກເປັນໃບແຍກຕາມ rule configuration.','Presentation-level certificates may be issued separately according to configured rules.'),
 ('TR-1021','PLAN_RECORD','APPROVAL_RECORD',10,'ແຜນປະຈຳປີທີ່ບັນທຶກ/ພິຈາລະນາແລ້ວ','Annual plan record','ໃຊ້ເປັນຖານອ້າງອີງສຳລັບຄຳຮ້ອງຄັ້ງຕໍ່ໄປຕາມ configuration.','Used as reference for later import applications according to configuration.'),
 ('TR-1007','IMPORT_NOTIFICATION','PERMIT',10,'ໃບແຈ້ງ/ໃບອະນຸຍາດນຳເຂົ້າ','Import notification/permit','ອອກຫຼັງຜ່ານ decision/authorization ຕາມ workflow.','Issued after configured decision/authorization workflow.')
 ) AS t(service_code,output_code,output_type,sequence_no,name_lo,name_en,description_lo,description_en)
)
INSERT INTO system.service_output(service_version_id,output_code,output_type,sequence_no,name_lo,name_en,description_lo,description_en,status)
SELECT v.service_version_id,x.output_code,x.output_type,x.sequence_no,x.name_lo,x.name_en,x.description_lo,x.description_en,'ACTIVE'
FROM v JOIN x USING(service_code)
ON CONFLICT(service_version_id,output_code) DO UPDATE SET output_type=EXCLUDED.output_type,sequence_no=EXCLUDED.sequence_no,name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,description_lo=EXCLUDED.description_lo,description_en=EXCLUDED.description_en,status='ACTIVE';

-- ============================================================================
-- MIGRATION: 000750_pwa_admin_field_foundation.sql
-- ============================================================================
-- LVSP v1.0: installable Web/PWA, central administration configuration and offline field capture staging.
-- Additive/non-destructive. Secrets must never be stored in system.platform_setting.

CREATE TABLE system.platform_setting (
  setting_code VARCHAR(120) PRIMARY KEY,
  category_code VARCHAR(60) NOT NULL DEFAULT 'GENERAL',
  name_lo TEXT NOT NULL,
  name_en TEXT,
  value_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  value_type VARCHAR(30) NOT NULL DEFAULT 'TEXT',
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  is_editable BOOLEAN NOT NULL DEFAULT TRUE,
  is_secret BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  CONSTRAINT ck_platform_setting_not_secret CHECK (is_secret = FALSE),
  CONSTRAINT ck_platform_setting_type CHECK (value_type IN ('TEXT','BOOLEAN','NUMBER','JSON'))
);
CREATE INDEX idx_platform_setting_category ON system.platform_setting(category_code,status);

INSERT INTO system.platform_setting(setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable)
VALUES
 ('APP_NAME_LO','BRANDING','ຊື່ລະບົບພາສາລາວ','Application name (Lao)',to_jsonb('ລະບົບບໍລິການສັດຕະວະແພດລາວ'::text),'TEXT',TRUE,TRUE),
 ('APP_NAME_EN','BRANDING','ຊື່ລະບົບພາສາອັງກິດ','Application name (English)',to_jsonb('Lao Veterinary Services Platform'::text),'TEXT',TRUE,TRUE),
 ('PUBLIC_SERVICE_CATALOG_ENABLED','PORTAL','ເປີດ Public Service Catalog','Public service catalog enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('STAFF_PWA_ENABLED','PWA','ເປີດ Staff PWA','Staff PWA enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('FIELD_PWA_ENABLED','PWA','ເປີດ Field PWA','Field PWA enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE),
 ('MAINTENANCE_BANNER','PORTAL','ຂໍ້ຄວາມແຈ້ງບຳລຸງຮັກສາ','Maintenance banner',to_jsonb(''::text),'TEXT',TRUE,TRUE)
ON CONFLICT (setting_code) DO NOTHING;

CREATE TABLE inspection.field_capture_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local_capture_id VARCHAR(120) NOT NULL,
  submitted_by_subject TEXT NOT NULL,
  submitted_by_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  capture_type VARCHAR(60) NOT NULL DEFAULT 'FIELD_NOTE',
  facility_text TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  captured_at TIMESTAMPTZ NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  sync_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
  linked_inspection_case_id UUID REFERENCES inspection.inspection_case(id) ON DELETE RESTRICT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  CONSTRAINT uq_field_capture_subject_local UNIQUE(submitted_by_subject,local_capture_id),
  CONSTRAINT ck_field_capture_lat CHECK(latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_field_capture_lon CHECK(longitude IS NULL OR longitude BETWEEN -180 AND 180)
);
CREATE INDEX idx_field_capture_status ON inspection.field_capture_draft(sync_status,received_at DESC);
CREATE INDEX idx_field_capture_inspection ON inspection.field_capture_draft(linked_inspection_case_id) WHERE linked_inspection_case_id IS NOT NULL;

-- Role permissions for safe central configuration. Existing SYSTEM_ADMIN/SECURITY_ADMIN continue to be enforced by API.
INSERT INTO security.permission(code,description) VALUES
 ('admin.platform.read','View LVSP platform administration and runtime configuration'),
 ('admin.platform.configure','Edit non-secret LVSP platform configuration'),
 ('admin.services.configure','Activate/deactivate or expose configured digital services'),
 ('field.capture.sync','Sync offline field capture drafts to LVSP')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN' AND p.code IN ('admin.platform.read','admin.platform.configure','admin.services.configure','field.capture.sync')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SECURITY_ADMIN' AND p.code IN ('admin.platform.read','admin.platform.configure')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code IN ('INSPECTOR','SENIOR_INSPECTOR') AND p.code='field.capture.sync'
ON CONFLICT DO NOTHING;

-- ============================================================================
-- MIGRATION: 000760_provincial_reporting_consolidation.sql
-- ============================================================================
-- LVSP v1.1: Provincial Veterinary Reporting & National Consolidation.
-- Source design is derived from the user-provided 2026 DVS consolidated Excel workbook
-- and provincial weekly/monthly reports. Additive/non-destructive.
-- Provincial names below are working reporting configuration only; they are not a replacement
-- for an officially imported master.admin_unit geography dataset.

CREATE SCHEMA IF NOT EXISTS reporting;

CREATE TABLE reporting.region (
  region_code VARCHAR(30) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reporting.region(region_code,name_lo,name_en,display_order) VALUES
 ('NORTH','ພາກເໜືອ','Northern Region',10),
 ('CENTRAL','ພາກກາງ','Central Region',20),
 ('SOUTH','ພາກໃຕ້','Southern Region',30)
ON CONFLICT (region_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,display_order=EXCLUDED.display_order,is_active=TRUE;

CREATE TABLE reporting.province_profile (
  province_code VARCHAR(40) PRIMARY KEY,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  region_code VARCHAR(30) REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  admin_unit_id UUID REFERENCES master.admin_unit(id) ON DELETE RESTRICT,
  display_order INTEGER NOT NULL DEFAULT 0,
  source_note TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reporting_province_region ON reporting.province_profile(region_code,status,display_order);

INSERT INTO reporting.province_profile(province_code,name_lo,name_en,region_code,display_order,source_note) VALUES
 ('PHONGSALY','ຜົ້ງສາລີ','Phongsaly','NORTH',1,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('LUANG_NAMTHA','ຫຼວງນ້ຳທາ','Luang Namtha','NORTH',2,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('OUDOMXAY','ອຸດົມໄຊ','Oudomxay','NORTH',3,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('BOKEO','ບໍ່ແກ້ວ','Bokeo','NORTH',4,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('LUANG_PRABANG','ຫຼວງພະບາງ','Luang Prabang','NORTH',5,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('HOUAPHANH','ຫົວພັນ','Houaphanh','NORTH',6,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XAYABOULY','ໄຊຍະບູລີ','Xayabouly','NORTH',7,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('VIENTIANE_CAPITAL','ນະຄອນຫຼວງວຽງຈັນ','Vientiane Capital','CENTRAL',8,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XIENG_KHOUANG','ຊຽງຂວາງ','Xieng Khouang','CENTRAL',9,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('VIENTIANE_PROVINCE','ວຽງຈັນ','Vientiane Province','CENTRAL',10,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('BOLIKHAMXAY','ບໍລິຄຳໄຊ','Bolikhamxay','CENTRAL',11,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('KHAMMOUANE','ຄຳມ່ວນ','Khammouane','CENTRAL',12,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SAVANNAKHET','ສະຫວັນນະເຂດ','Savannakhet','CENTRAL',13,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('XAYSOMBOUN','ໄຊສົມບູນ','Xaysomboun','CENTRAL',14,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SALAVAN','ສາລະວັນ','Salavan','SOUTH',15,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('SEKONG','ເຊກອງ','Sekong','SOUTH',16,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('CHAMPASAK','ຈຳປາສັກ','Champasak','SOUTH',17,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.'),
 ('ATTAPEU','ອັດຕະປື','Attapeu','SOUTH',18,'Working reporting list derived from user-provided DVS consolidated Excel workbook; link to official master geography when approved.')
ON CONFLICT (province_code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,region_code=EXCLUDED.region_code,display_order=EXCLUDED.display_order,updated_at=now();

CREATE TABLE reporting.region_staff_assignment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_code VARCHAR(30) NOT NULL REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  staff_subject TEXT NOT NULL,
  staff_user_id UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  assignment_role VARCHAR(30) NOT NULL DEFAULT 'DATA_ENTRY',
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_assignment_role CHECK(assignment_role IN ('DATA_ENTRY','REVIEWER','MANAGER')),
  CONSTRAINT ck_reporting_assignment_dates CHECK(effective_to IS NULL OR effective_to>=effective_from)
);
CREATE INDEX idx_reporting_staff_subject ON reporting.region_staff_assignment(staff_subject,status,region_code);
CREATE UNIQUE INDEX uq_reporting_active_staff_region_role ON reporting.region_staff_assignment(region_code,staff_subject,assignment_role) WHERE status='ACTIVE' AND effective_to IS NULL;

CREATE TABLE reporting.report_submission (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  province_code VARCHAR(40) NOT NULL REFERENCES reporting.province_profile(province_code) ON DELETE RESTRICT,
  report_type VARCHAR(30) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  revision_no INTEGER NOT NULL DEFAULT 1 CHECK(revision_no>0),
  supersedes_report_id UUID REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  source_channel VARCHAR(40) NOT NULL DEFAULT 'DOCUMENT',
  source_format VARCHAR(30),
  source_filename TEXT,
  source_reference TEXT,
  source_document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  received_by_subject TEXT,
  assigned_region_code VARCHAR(30) REFERENCES reporting.region(region_code) ON DELETE RESTRICT,
  assigned_to_subject TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
  include_in_consolidation BOOLEAN NOT NULL DEFAULT TRUE,
  summary_note TEXT,
  data_entry_note TEXT,
  ready_for_review_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  verified_by_subject TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_period CHECK(period_end>=period_start),
  CONSTRAINT ck_reporting_type CHECK(report_type IN ('WEEKLY','MONTHLY','QUARTERLY','SEMI_ANNUAL','ANNUAL','AD_HOC')),
  CONSTRAINT ck_reporting_status CHECK(status IN ('RECEIVED','DATA_ENTRY','READY_FOR_REVIEW','VERIFIED','REJECTED','SUPERSEDED')),
  CONSTRAINT ck_reporting_channel CHECK(source_channel IN ('DOCUMENT','EMAIL','PAPER','WHATSAPP','MESSAGING','DIRECT_ENTRY','OTHER'))
);
CREATE INDEX idx_reporting_submission_period ON reporting.report_submission(period_start,period_end,status);
CREATE INDEX idx_reporting_submission_province ON reporting.report_submission(province_code,period_end DESC,status);
CREATE INDEX idx_reporting_submission_assigned ON reporting.report_submission(assigned_to_subject,status,period_end DESC);
CREATE UNIQUE INDEX uq_reporting_submission_revision ON reporting.report_submission(province_code,report_type,period_start,period_end,revision_no);

CREATE TABLE reporting.indicator_definition (
  metric_code VARCHAR(100) PRIMARY KEY,
  section_code VARCHAR(60) NOT NULL,
  name_lo TEXT NOT NULL,
  name_en TEXT,
  default_unit_code VARCHAR(30),
  aggregation_method VARCHAR(20) NOT NULL DEFAULT 'SUM',
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source_sheet TEXT,
  CONSTRAINT ck_reporting_aggregation CHECK(aggregation_method IN ('SUM','LATEST','AVERAGE','NONE'))
);

INSERT INTO reporting.indicator_definition(metric_code,section_code,name_lo,name_en,default_unit_code,display_order,source_sheet) VALUES
 ('VACCINATION.POPULATION','VACCINATION','ຈຳນວນຝູງສັດ','Animal population','HEAD',10,'1. ສັກຢາປ້ອງກັນສັດ'),
 ('VACCINATION.VACCINATED','VACCINATION','ຈຳນວນສັກຢາໄດ້','Animals vaccinated','HEAD',20,'1. ສັກຢາປ້ອງກັນສັດ'),
 ('TREATMENT.TREATED','TREATMENT','ຈຳນວນສັດປິ່ນປົວ','Animals treated','HEAD',30,'2. ປິ່ນປົວສັດ'),
 ('TREATMENT.DEATHS','TREATMENT','ຈຳນວນສັດຕາຍ','Animal deaths','HEAD',40,'2. ປິ່ນປົວສັດ'),
 ('SLAUGHTER.INSPECTED','SLAUGHTER_INSPECTION','ຈຳນວນສັດກວດກາກ່ອນ/ຫຼັງຂ້າ','Animals slaughtered/inspected','HEAD',50,'11. ອະນາໄມຊີ້ນຂ້າສັດ ບໍລິໂພກ')
ON CONFLICT (metric_code) DO NOTHING;

CREATE TABLE reporting.indicator_value (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  metric_code VARCHAR(100) NOT NULL REFERENCES reporting.indicator_definition(metric_code) ON DELETE RESTRICT,
  species_code VARCHAR(60) NOT NULL DEFAULT 'ALL',
  dimension_key VARCHAR(120) NOT NULL DEFAULT '',
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  value_numeric NUMERIC(20,4) NOT NULL DEFAULT 0,
  unit_code VARCHAR(30),
  source_note TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reporting_indicator UNIQUE(report_id,metric_code,species_code,dimension_key)
);
CREATE INDEX idx_reporting_indicator_metric ON reporting.indicator_value(metric_code,species_code,report_id);

CREATE TABLE reporting.trade_stat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  movement_type VARCHAR(20) NOT NULL,
  commodity_class VARCHAR(40) NOT NULL,
  purpose_code VARCHAR(40),
  item_name TEXT,
  species_code VARCHAR(60),
  checkpoint_in TEXT,
  checkpoint_out TEXT,
  origin_text TEXT,
  destination_text TEXT,
  company_name TEXT,
  transport_mode TEXT,
  quantity NUMERIC(20,4),
  unit_code VARCHAR(30),
  weight_ton NUMERIC(20,4),
  value_amount NUMERIC(20,2),
  currency_code VARCHAR(10) NOT NULL DEFAULT 'USD',
  source_note TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_trade_movement CHECK(movement_type IN ('IMPORT','EXPORT','TRANSIT','DOMESTIC_MOVEMENT')),
  CONSTRAINT ck_reporting_trade_class CHECK(commodity_class IN ('LIVE_ANIMAL','ANIMAL_PRODUCT','EGG','ANIMAL_BYPRODUCT','AQUATIC_ANIMAL','OTHER')),
  CONSTRAINT ck_reporting_trade_status CHECK(status IN ('ACTIVE','VOID'))
);
CREATE INDEX idx_reporting_trade_report ON reporting.trade_stat(report_id,status);
CREATE INDEX idx_reporting_trade_movement ON reporting.trade_stat(movement_type,commodity_class,currency_code);

CREATE TABLE reporting.activity_note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reporting.report_submission(id) ON DELETE RESTRICT,
  note_type VARCHAR(30) NOT NULL DEFAULT 'ACTIVITY',
  category_code VARCHAR(60),
  title TEXT,
  description TEXT NOT NULL,
  result_text TEXT,
  is_next_period_plan BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_reporting_note_type CHECK(note_type IN ('ACTIVITY','ISSUE','RISK','PLAN','OTHER'))
);
CREATE INDEX idx_reporting_activity_report ON reporting.activity_note(report_id,status,note_type);

CREATE TABLE reporting.monthly_report_draft (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_year INTEGER NOT NULL CHECK(report_year BETWEEN 2000 AND 2200),
  report_month INTEGER NOT NULL CHECK(report_month BETWEEN 1 AND 12),
  title_lo TEXT,
  narrative_lo TEXT,
  figures_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
  created_by_subject TEXT,
  reviewed_by_subject TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reporting_monthly_draft UNIQUE(report_year,report_month),
  CONSTRAINT ck_reporting_monthly_draft_status CHECK(status IN ('DRAFT','REVIEWED','FINAL'))
);

INSERT INTO system.platform_setting(setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable)
VALUES ('REPORTING_MODULE_ENABLED','MODULES','ເປີດ Module ລາຍງານແຂວງ','Provincial reporting module enabled','true'::jsonb,'BOOLEAN',TRUE,TRUE)
ON CONFLICT (setting_code) DO NOTHING;

INSERT INTO security.permission(code,description) VALUES
 ('reporting.read','View provincial veterinary reports and national consolidation'),
 ('reporting.enter','Register incoming provincial reports and enter required indicators'),
 ('reporting.verify','Review and verify provincial reporting data'),
 ('reporting.admin','Configure regional work allocation for provincial reporting')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN' AND p.code LIKE 'reporting.%'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('reporting.read','reporting.enter')
WHERE r.code IN ('DATA_STEWARD','EPIDEMIOLOGIST')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('reporting.read','reporting.verify')
WHERE r.code IN ('TECHNICAL_REVIEWER','MANAGEMENT_VIEWER')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- MIGRATION: 000770_vet_drug_reference_automation.sql
-- ============================================================================
-- LVSP v1.2.0 — Veterinary Drug Controlled Reference Data & Regulatory Automation
-- Reuses the proven admin(4) controlled vocabularies while making them database-configurable.
-- ATCvet labels are reference mappings; official codes must remain reviewable and updateable.

CREATE TABLE lookup.veterinary_drug_reference_term (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_code VARCHAR(40) NOT NULL,
  code VARCHAR(80) NOT NULL,
  parent_code VARCHAR(80),
  value_text TEXT NOT NULL,
  name_lo TEXT,
  name_en TEXT,
  sort_order INTEGER NOT NULL DEFAULT 100,
  source_system VARCHAR(80),
  source_reference TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(domain_code,code)
);
CREATE INDEX idx_vet_drug_reference_domain_active ON lookup.veterinary_drug_reference_term(domain_code,is_active,sort_order);
CREATE TRIGGER trg_vet_drug_reference_updated_at BEFORE UPDATE ON lookup.veterinary_drug_reference_term FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TABLE product.veterinary_registration_number_sequence (
  prefix VARCHAR(10) NOT NULL,
  year_month CHAR(6) NOT NULL,
  last_no INTEGER NOT NULL DEFAULT 0 CHECK(last_no>=0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(prefix,year_month)
);

ALTER TABLE product.product_regulatory_profile
  ADD COLUMN IF NOT EXISTS registration_number_source VARCHAR(20) NOT NULL DEFAULT 'LEGACY';

INSERT INTO lookup.veterinary_drug_reference_term(domain_code,code,parent_code,value_text,name_lo,name_en,sort_order,source_system,source_reference,metadata)
VALUES
('CATEGORY','VACCINE',NULL,'ວັກຊິນ (Vaccine)','ວັກຊິນ (Vaccine)','Vaccine',1,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIMICROBIAL',NULL,'ຢາຕ້ານເຊື້ອ (Antibiotic / Antimicrobial)','ຢາຕ້ານເຊື້ອ (Antibiotic / Antimicrobial)','Antibiotic / Antimicrobial',2,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIVIRAL',NULL,'ຢາຕ້ານໄວຣັດ (Antiviral)','ຢາຕ້ານໄວຣັດ (Antiviral)','Antiviral',3,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIFUNGAL',NULL,'ຢາຕ້ານເຊື້ອລາ (Antifungal)','ຢາຕ້ານເຊື້ອລາ (Antifungal)','Antifungal',4,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTIPARASITIC',NULL,'ຢາຕ້ານກາຝາກ (Antiparasitic)','ຢາຕ້ານກາຝາກ (Antiparasitic)','Antiparasitic',5,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','VITAMIN_MINERAL_SUPPLEMENT',NULL,'ວິຕາມິນ, ແຮ່ທາດ ແລະ ສານເສີມອາຫານສັດ (Vitamin / Mineral / Supplement)','ວິຕາມິນ, ແຮ່ທາດ ແລະ ສານເສີມອາຫານສັດ (Vitamin / Mineral / Supplement)','Vitamin / Mineral / Supplement',6,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTI_INFLAMMATORY_ANALGESIC',NULL,'ຢາຕ້ານການອັກເສບ ແລະ ແກ້ປວດ (Anti-inflammatory / Analgesic)','ຢາຕ້ານການອັກເສບ ແລະ ແກ້ປວດ (Anti-inflammatory / Analgesic)','Anti-inflammatory / Analgesic',7,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','HORMONAL_REPRODUCTIVE',NULL,'ຢາຮໍໂມນ ແລະ ຢາຄວບຄຸມລະບົບສືບພັນ (Hormonal / Reproductive)','ຢາຮໍໂມນ ແລະ ຢາຄວບຄຸມລະບົບສືບພັນ (Hormonal / Reproductive)','Hormonal / Reproductive',8,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANTISEPTIC_DISINFECTANT',NULL,'ຢາຂ້າເຊື້ອ (Antiseptic / Disinfectant)','ຢາຂ້າເຊື້ອ (Antiseptic / Disinfectant)','Antiseptic / Disinfectant',9,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','ANESTHETIC_SEDATIVE',NULL,'ຢາສະຫຼົບ ແລະ ຢາລະງັບປະສາດ (Anesthetic / Sedative)','ຢາສະຫຼົບ ແລະ ຢາລະງັບປະສາດ (Anesthetic / Sedative)','Anesthetic / Sedative',10,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('CATEGORY','OTHER_SPECIFIC_THERAPY',NULL,'ຢາອື່ນໆ ຫຼື ຢາປິ່ນປົວສະເພາະທາງ (Other / Specific Therapy)','ຢາອື່ນໆ ຫຼື ຢາປິ່ນປົວສະເພາະທາງ (Other / Specific Therapy)','Other / Specific Therapy',11,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),

('DOSAGE_GROUP','inj',NULL,'inj','ຢາສັກ (Injectables)','Injectables',1,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),
('DOSAGE_GROUP','oral',NULL,'oral','ຢາທາງປາກ (Oral Forms)','Oral Forms',2,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),
('DOSAGE_GROUP','topical',NULL,'topical','ພາຍນອກ (Topical Forms)','Topical Forms',3,'LVSP_LEGACY','admin(4) dependent dropdown','{}'),

('DOSAGE_FORM','LYOPHILIZED_INJECTION','inj','ຜົງແຫ້ງສຳລັບສັກ (Lyophilized powder for injection)','ຜົງແຫ້ງສຳລັບສັກ','Lyophilized powder for injection',1,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SOLUTION_INJECTION','inj','ຢານ້ຳສຳເລັດຮູບ (Solution for injection)','ຢານ້ຳສຳເລັດຮູບ','Solution for injection',2,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SUSPENSION_INJECTION','inj','ຢາທາດແຂວນລອຍ (Suspension for injection)','ຢາທາດແຂວນລອຍ','Suspension for injection',3,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_SOLUTION','oral','ຢານ້ຳກິນ (Oral solution)','ຢານ້ຳກິນ','Oral solution',10,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_POWDER','oral','ຜົງລະລາຍນ້ຳກິນ (Oral powder / Water Soluble Powder)','ຜົງລະລາຍນ້ຳກິນ','Oral powder / Water Soluble Powder',11,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','PREMIX','oral','ຢາປະສົມອາຫານສັດ (Premix)','ຢາປະສົມອາຫານສັດ','Premix',12,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','TABLET_BOLUS','oral','ຢາເມັດ / ຢາເມັດຂະໜາດໃຫຍ່ (Tablet / Bolus)','ຢາເມັດ / ໂບລັສ','Tablet / Bolus',13,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','CHEWABLE_TABLET','oral','ຢາເມັດແບບຫຍ້ຳ (Chewable Tablet)','ຢາເມັດແບບຫຍ້ຳ','Chewable Tablet',14,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','CAPSULE','oral','ແຄັບຊູນ (Capsule)','ແຄັບຊູນ','Capsule',15,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','ORAL_PASTE','oral','ຢາປ້າຍ / ຢາເນື້ອຄຣີມ (Oral paste)','ຢາປ້າຍ / ຢາເນື້ອຄຣີມ','Oral paste',16,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','POUR_ON','topical','ຢາຢອດຫຼັງ / ລາດຫຼັງ (Pour-on solution)','ຢາຢອດຫຼັງ / ລາດຫຼັງ','Pour-on solution',20,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SPRAY','topical','ຢາພົ່ນ (Spray solution)','ຢາພົ່ນ','Spray solution',21,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','OINTMENT_CREAM','topical','ຢາຂີ້ເຜິ້ງ / ຄຣີມທາແຜ (Ointment / Cream)','ຢາຂີ້ເຜິ້ງ / ຄຣີມ','Ointment / Cream',22,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','SPOT_ON','topical','ຢາຢອດສະເພາະຈຸດ (Spot-On)','ຢາຢອດສະເພາະຈຸດ','Spot-On',23,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),
('DOSAGE_FORM','DIP_SHAMPOO','topical','ຢາອາບນ້ຳ / ຢາແຊ່ (Dip / Shampoo)','ຢາອາບນ້ຳ / ຢາແຊ່','Dip / Shampoo',24,'EDQM_ALIGNED','Controlled term seed; verify against current EDQM Standard Terms','{}'),

('DISTRIBUTION','POM',NULL,'POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ','POM — ຕ້ອງມີໃບສັ່ງສັດຕະວະແພດ','Prescription Only Medicine',1,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('DISTRIBUTION','OTC',NULL,'OTC — ຈຳໜ່າຍທົ່ວໄປ','OTC — ຈຳໜ່າຍທົ່ວໄປ','Over the Counter',2,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),
('DISTRIBUTION','CONTROLLED',NULL,'ຄວບຄຸມພິເສດ (Controlled)','ຄວບຄຸມພິເສດ (Controlled)','Controlled',3,'LVSP_LEGACY','admin(4) controlled vocabulary','{}'),

('ROUTE','IM',NULL,'ສັກເຂົ້າກ້າມ (IM)','ສັກເຂົ້າກ້າມ','Intramuscular',1,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','SC',NULL,'ສັກໃຕ້ຜິວໜັງ (SC)','ສັກໃຕ້ຜິວໜັງ','Subcutaneous',2,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IV',NULL,'ສັກເຂົ້າເສັ້ເລືອດ (IV)','ສັກເຂົ້າເສັ້ເລືອດ','Intravenous',3,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IP',NULL,'ສັກເຂົ້າຊ່ອງທ້ອງ (IP)','ສັກເຂົ້າຊ່ອງທ້ອງ','Intraperitoneal',4,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','ORAL',NULL,'ກິນ (PO / Oral)','ກິນ','Oral',5,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','DRINKING_WATER',NULL,'ປະສົມນ້ຳດື່ມ','ປະສົມນ້ຳດື່ມ','In drinking water',6,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','FEED',NULL,'ປະສົມອາຫານສັດ','ປະສົມອາຫານສັດ','In feed',7,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','TOPICAL',NULL,'ທາຜິວໜັງ (Topical)','ທາຜິວໜັງ','Topical',8,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','POUR_ON',NULL,'ຢອດຫຼັງ (Pour-on)','ຢອດຫຼັງ','Pour-on',9,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','SPOT_ON',NULL,'ຢອດສະເພາະຈຸດ (Spot-on)','ຢອດສະເພາະຈຸດ','Spot-on',10,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','SPRAY',NULL,'ພົ່ນລະອອງ (Spray / Aerosol)','ພົ່ນລະອອງ','Spray / Aerosol',11,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','EYE_EAR',NULL,'ຢອດຕາ / ຢອດຫູ','ຢອດຕາ / ຢອດຫູ','Eye / Ear',12,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','INTRAMAMMARY',NULL,'ສອດເຕົ້ານົມ (Intramammary)','ສອດເຕົ້ານົມ','Intramammary',13,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','IMMERSION',NULL,'ແຊ່ນ້ຳ (Immersion)','ແຊ່ນ້ຳ','Immersion',14,'EDQM_ALIGNED','Route/method seed from legacy','{}'),
('ROUTE','OCULAR',NULL,'ຢອດຕາ (Ocular)','ຢອດຕາ','Ocular',15,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),
('ROUTE','INTRANASAL',NULL,'ຢອດດັງ (Intranasal)','ຢອດດັງ','Intranasal',16,'EDQM_ALIGNED','Route seed from legacy; map to current EDQM Standard Terms','{}'),

('ATCVET','QA',NULL,'QA — ລະບົບຍ່ອຍອາຫານ & ເມຕາໂບລິຊຶມ','QA — ລະບົບຍ່ອຍອາຫານ & ເມຕາໂບລິຊຶມ','Alimentary tract and metabolism',1,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QB',NULL,'QB — ເລືອດ & ອະໄວຍະວະສ້າງເລືອດ','QB — ເລືອດ & ອະໄວຍະວະສ້າງເລືອດ','Blood and blood forming organs',2,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QC',NULL,'QC — ຫົວໃຈ & ຫຼອດເລືອດ','QC — ຫົວໃຈ & ຫຼອດເລືອດ','Cardiovascular system',3,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QD',NULL,'QD — ຜິວໜັງ','QD — ຜິວໜັງ','Dermatologicals',4,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIFUNGAL","ANTISEPTIC_DISINFECTANT"]}'),
('ATCVET','QG',NULL,'QG — ສືບພັນ & ຮໍໂມນເພດ','QG — ສືບພັນ & ຮໍໂມນເພດ','Genito urinary system and sex hormones',5,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["HORMONAL_REPRODUCTIVE"]}'),
('ATCVET','QH',NULL,'QH — ຮໍໂມນລະບົບ','QH — ຮໍໂມນລະບົບ','Systemic hormonal preparations',6,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["HORMONAL_REPRODUCTIVE"]}'),
('ATCVET','QI',NULL,'QI — ວັກຊີນ/ຜະລິດຕະພັນພູມຄຸ້ມກັນ','QI — ວັກຊີນ/ຜະລິດຕະພັນພູມຄຸ້ມກັນ','Immunologicals',7,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["VACCINE"]}'),
('ATCVET','QJ',NULL,'QJ — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','QJ — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','Antiinfectives for systemic use',8,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL","ANTIVIRAL","ANTIFUNGAL"]}'),
('ATCVET','QJ01','QJ','QJ01 — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ (Antibacterials)','QJ01 — ຢາຕ້ານເຊື້ອໃຊ້ທົ່ວຮ່າງ','Antibacterials for systemic use',9,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL"]}'),
('ATCVET','QJ05','QJ','QJ05 — ຢາຕ້ານໄວຣັດ (Antivirals)','QJ05 — ຢາຕ້ານໄວຣັດ','Antivirals for systemic use',10,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIVIRAL"]}'),
('ATCVET','QJ51','QJ','QJ51 — ຢາຕ້ານເຊື້ອສອດເຕົ້ານົມ (Intramammary)','QJ51 — ຢາຕ້ານເຊື້ອສອດເຕົ້ານົມ','Antibacterials for intramammary use',11,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIMICROBIAL"]}'),
('ATCVET','QL',NULL,'QL — ຢາຕ້ານເນື້ອງອກ/ປັບພູມ','QL — ຢາຕ້ານເນື້ອງອກ/ປັບພູມ','Antineoplastic and immunomodulating agents',12,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QM',NULL,'QM — ກ້າມ & ກະດູກ','QM — ກ້າມ & ກະດູກ','Musculo-skeletal system',13,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTI_INFLAMMATORY_ANALGESIC"]}'),
('ATCVET','QM01','QM','QM01 — ຢາຕ້ານການອັກເສບ (NSAIDs)','QM01 — ຢາຕ້ານການອັກເສບ','Anti-inflammatory and antirheumatic products',14,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTI_INFLAMMATORY_ANALGESIC"]}'),
('ATCVET','QN',NULL,'QN — ລະບົບປະສາດ','QN — ລະບົບປະສາດ','Nervous system',15,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QN01','QN','QN01 — ຢາສະຫຼົບ / ຢາຊາ (Anaesthetics)','QN01 — ຢາສະຫຼົບ / ຢາຊາ','Anaesthetics',16,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QN05','QN','QN05 — ຢາລະງັບປະສາດ (Sedatives)','QN05 — ຢາລະງັບປະສາດ','Sedatives',17,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANESTHETIC_SEDATIVE"]}'),
('ATCVET','QP',NULL,'QP — ຢາຕ້ານກາຝາກ, ຂ້າແມງໄມ້','QP — ຢາຕ້ານກາຝາກ, ຂ້າແມງໄມ້','Antiparasitic products, insecticides and repellents',18,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP51','QP','QP51 — ຢາຕ້ານໂປຣໂຕຊົວ (Antiprotozoals)','QP51 — ຢາຕ້ານໂປຣໂຕຊົວ','Antiprotozoals',19,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP52','QP','QP52 — ຢາຖ່າຍພະຍາດ (Anthelmintics)','QP52 — ຢາຖ່າຍພະຍາດ','Anthelmintics',20,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP53','QP','QP53 — ຢາກຳຈັດກາຝາກຕົວນອກ ເຊັ່ນ ເຫັບ/ໝັດ (Ectoparasiticides)','QP53 — ຢາກຳຈັດກາຝາກຕົວນອກ','Ectoparasiticides',21,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QP54','QP','QP54 — ຢາກຳຈັດກາຝາກພາຍໃນ+ພາຍນອກ (Endectocides)','QP54 — ຢາກຳຈັດກາຝາກພາຍໃນ+ພາຍນອກ','Endectocides',22,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["ANTIPARASITIC"]}'),
('ATCVET','QR',NULL,'QR — ລະບົບຫາຍໃຈ','QR — ລະບົບຫາຍໃຈ','Respiratory system',23,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QS',NULL,'QS — ຕາ/ຫູ','QS — ຕາ/ຫູ','Sensory organs',24,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{}'),
('ATCVET','QV',NULL,'QV — ອື່ນໆ (Various)','QV — ອື່ນໆ','Various',25,'WHO_ATCVET','ATCvet Index; verify current code before regulatory use','{"categoryCodes":["OTHER_SPECIFIC_THERAPY"]}')
ON CONFLICT(domain_code,code) DO UPDATE SET
  parent_code=excluded.parent_code,value_text=excluded.value_text,name_lo=excluded.name_lo,name_en=excluded.name_en,
  sort_order=excluded.sort_order,source_system=excluded.source_system,source_reference=excluded.source_reference,metadata=excluded.metadata,is_active=TRUE;

COMMENT ON TABLE lookup.veterinary_drug_reference_term IS 'Configurable controlled values for veterinary drug regulatory forms. Seeds preserve proven legacy behavior and may be updated through governance without changing product records.';
COMMENT ON COLUMN product.product_regulatory_profile.registration_number_source IS 'AUTO, MANUAL, or LEGACY/EXISTING. Manual values remain audited and uniqueness constrained by registration_no.';

-- ============================================================================
-- MIGRATION: 000780_annual_import_plan_operational.sql
-- ============================================================================
-- LVSP v0.9.0 — Annual Import Plan operational core
-- Non-destructive extension based on the approved annual-plan workflow and legacy balance view.
-- Actual balance is calculated from cleared quantities; this migration does not deduct on permit approval.

ALTER TABLE trade.import_plan
  ADD COLUMN IF NOT EXISTS application_ref_no VARCHAR(120),
  ADD COLUMN IF NOT EXISTS application_ref_date DATE,
  ADD COLUMN IF NOT EXISTS decision_no VARCHAR(120),
  ADD COLUMN IF NOT EXISTS decision_date DATE,
  ADD COLUMN IF NOT EXISTS valid_from DATE,
  ADD COLUMN IF NOT EXISTS valid_to DATE,
  ADD COLUMN IF NOT EXISTS approved_by TEXT,
  ADD COLUMN IF NOT EXISTS approval_conditions TEXT,
  ADD COLUMN IF NOT EXISTS company_name_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS company_address_snapshot TEXT,
  ADD COLUMN IF NOT EXISTS current_version_no INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT;

ALTER TABLE trade.import_plan
  ADD CONSTRAINT ck_import_plan_validity_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from);

ALTER TABLE trade.import_plan_item
  ADD COLUMN IF NOT EXISTS item_code VARCHAR(120),
  ADD COLUMN IF NOT EXISTS line_mode VARCHAR(30) NOT NULL DEFAULT 'ITEM',
  ADD COLUMN IF NOT EXISTS group_code VARCHAR(60),
  ADD COLUMN IF NOT EXISTS group_name TEXT,
  ADD COLUMN IF NOT EXISTS planned_item_count INTEGER,
  ADD COLUMN IF NOT EXISTS planned_pack_count NUMERIC(18,3),
  ADD COLUMN IF NOT EXISTS record_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE';

ALTER TABLE trade.import_plan_item
  ADD CONSTRAINT ck_import_plan_item_line_mode CHECK(line_mode IN ('ITEM','SUMMARY_GROUP')),
  ADD CONSTRAINT ck_import_plan_item_count CHECK(planned_item_count IS NULL OR planned_item_count >= 0),
  ADD CONSTRAINT ck_import_plan_pack_count CHECK(planned_pack_count IS NULL OR planned_pack_count >= 0),
  ADD CONSTRAINT ck_import_plan_item_record_status CHECK(record_status IN ('ACTIVE','RETIRED'));

-- Replace the original full-row uniqueness with active-line uniqueness so DRAFT edits can retire
-- superseded rows without hard-deleting regulatory records or breaking historical references.
ALTER TABLE trade.import_plan_item DROP CONSTRAINT IF EXISTS import_plan_item_plan_id_item_no_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_import_plan_item_active_no ON trade.import_plan_item(plan_id,item_no) WHERE record_status='ACTIVE';

CREATE INDEX IF NOT EXISTS idx_import_plan_item_code ON trade.import_plan_item(plan_id,item_code) WHERE item_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_import_plan_item_group ON trade.import_plan_item(plan_id,group_code) WHERE group_code IS NOT NULL;

-- Immutable approved snapshots. The current trade.import_plan/import_plan_item rows remain the operational materialization.
CREATE TABLE IF NOT EXISTS trade.import_plan_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  version_no INTEGER NOT NULL CHECK(version_no > 0),
  version_type VARCHAR(30) NOT NULL DEFAULT 'INITIAL' CHECK(version_type IN ('INITIAL','AMENDMENT','CORRECTION')),
  reason TEXT,
  status VARCHAR(30) NOT NULL,
  plan_no VARCHAR(120) NOT NULL,
  company_id UUID NOT NULL REFERENCES master.company(party_id) ON DELETE RESTRICT,
  company_site_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT,
  company_name_snapshot TEXT,
  company_address_snapshot TEXT,
  plan_year INTEGER NOT NULL,
  application_date DATE,
  application_ref_no VARCHAR(120),
  application_ref_date DATE,
  approval_no VARCHAR(120),
  approval_date DATE,
  decision_no VARCHAR(120),
  decision_date DATE,
  valid_from DATE,
  valid_to DATE,
  approved_by TEXT,
  approval_conditions TEXT,
  notes TEXT,
  snapshotted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id,version_no),
  CONSTRAINT ck_import_plan_version_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS idx_import_plan_version_plan ON trade.import_plan_version(plan_id,version_no DESC);

CREATE TABLE IF NOT EXISTS trade.import_plan_item_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_version_id UUID NOT NULL REFERENCES trade.import_plan_version(id) ON DELETE RESTRICT,
  source_plan_item_id UUID REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  item_no INTEGER NOT NULL CHECK(item_no > 0),
  item_code VARCHAR(120),
  line_mode VARCHAR(30) NOT NULL DEFAULT 'ITEM' CHECK(line_mode IN ('ITEM','SUMMARY_GROUP')),
  group_code VARCHAR(60),
  group_name TEXT,
  item_type VARCHAR(40) NOT NULL,
  product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
  device_id UUID REFERENCES product.veterinary_device(id) ON DELETE RESTRICT,
  package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
  item_name TEXT NOT NULL,
  registration_no VARCHAR(120),
  package_description TEXT,
  planned_quantity NUMERIC(18,3) NOT NULL DEFAULT 0,
  planned_item_count INTEGER,
  planned_pack_count NUMERIC(18,3),
  unit_code VARCHAR(40),
  planned_value NUMERIC(18,2),
  currency_code VARCHAR(10),
  manufacturer_name TEXT,
  manufacturer_country TEXT,
  notes TEXT,
  UNIQUE(plan_version_id,item_no)
);
CREATE INDEX IF NOT EXISTS idx_import_plan_item_version_parent ON trade.import_plan_item_version(plan_version_id,item_no);

-- Read-only balance: planned amount minus ACTUAL cleared amount linked to the annual-plan item.
-- This deliberately does not reduce the plan when an application or permit is merely approved.
CREATE OR REPLACE VIEW analytics.v_import_plan_item_balance AS
SELECT
  pi.id AS plan_item_id,
  pi.plan_id,
  pi.item_no,
  pi.item_code,
  pi.item_type,
  pi.item_name,
  pi.registration_no,
  pi.package_description,
  pi.unit_code,
  pi.planned_quantity,
  pi.planned_value,
  COALESCE(SUM(COALESCE(iai.cleared_quantity,iai.cleared_packs,0)),0)::NUMERIC(18,3) AS actual_cleared_quantity,
  (pi.planned_quantity - COALESCE(SUM(COALESCE(iai.cleared_quantity,iai.cleared_packs,0)),0))::NUMERIC(18,3) AS remaining_quantity,
  COUNT(DISTINCT CASE WHEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0) > 0 THEN iai.application_id END)::INTEGER AS clearance_count
FROM trade.import_plan_item pi
LEFT JOIN trade.import_application_item iai ON iai.plan_item_id=pi.id
WHERE pi.record_status='ACTIVE'
GROUP BY pi.id,pi.plan_id,pi.item_no,pi.item_code,pi.item_type,pi.item_name,pi.registration_no,pi.package_description,pi.unit_code,pi.planned_quantity,pi.planned_value;

-- Regulatory snapshots are history; do not hard-delete them.
CREATE TRIGGER trg_no_delete_import_plan_version BEFORE DELETE ON trade.import_plan_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER trg_no_delete_import_plan_item_version BEFORE DELETE ON trade.import_plan_item_version
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

-- ============================================================================
-- MIGRATION: 000790_flexible_annual_import_plan.sql
-- ============================================================================
-- LVSP 000790: Flexible Annual Import Plan foundation
-- Additive extension of 000780. Core 000780 tables are NOT altered.

DO $$
BEGIN
  IF to_regclass('trade.import_plan') IS NULL
     OR to_regclass('trade.import_plan_item') IS NULL THEN
    RAISE EXCEPTION '000790 requires migration 000780 first';
  END IF;
END $$;

CREATE TABLE trade.import_plan_profile (
  import_plan_id uuid PRIMARY KEY REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  detail_level varchar(20) NOT NULL DEFAULT 'ITEM'
    CHECK (detail_level IN ('ITEM','CATEGORY','HYBRID')),
  movement_type varchar(20) NOT NULL DEFAULT 'IMPORT'
    CHECK (movement_type IN ('IMPORT','EXPORT','TRANSIT','RE_EXPORT')),
  service_type varchar(80) NOT NULL DEFAULT 'VET_DRUG_DEVICE',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE trade.import_plan_item_profile (
  plan_item_id uuid PRIMARY KEY REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  parent_plan_item_id uuid REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  scope_type varchar(20) NOT NULL DEFAULT 'ITEM'
    CHECK (scope_type IN ('ITEM','CATEGORY','GROUP')),
  category_code varchar(100),
  planned_value_usd numeric(20,2) CHECK (planned_value_usd IS NULL OR planned_value_usd>=0),
  planned_item_count integer CHECK (planned_item_count IS NULL OR planned_item_count>=0),
  tracking_basis varchar(30) NOT NULL DEFAULT 'QUANTITY'
    CHECK (tracking_basis IN ('QUANTITY','VALUE','QUANTITY_VALUE','COUNT_VALUE','REFERENCE_ONLY')),
  count_is_reference boolean NOT NULL DEFAULT true,
  allow_item_mapping boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (parent_plan_item_id IS NULL OR parent_plan_item_id<>plan_item_id)
);

CREATE INDEX idx_import_plan_item_profile_parent
  ON trade.import_plan_item_profile(parent_plan_item_id);
CREATE INDEX idx_import_plan_item_profile_category
  ON trade.import_plan_item_profile(category_code) WHERE category_code IS NOT NULL;

CREATE TABLE trade.import_plan_allocation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_item_id uuid NOT NULL REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  source_entity_type varchar(60) NOT NULL,
  source_entity_id uuid NOT NULL,
  allocation_stage varchar(20) NOT NULL
    CHECK (allocation_stage IN ('APPLICATION','PERMIT','CLEARANCE','ADJUSTMENT')),
  allocated_quantity numeric(20,6) CHECK (allocated_quantity IS NULL OR allocated_quantity>=0),
  source_unit varchar(40),
  allocated_value_usd numeric(20,2) CHECK (allocated_value_usd IS NULL OR allocated_value_usd>=0),
  mapping_method varchar(20) NOT NULL DEFAULT 'MANUAL'
    CHECK (mapping_method IN ('AUTO','MANUAL','IMPORTED','RULE')),
  confidence_score numeric(5,4) CHECK (confidence_score IS NULL OR confidence_score BETWEEN 0 AND 1),
  mapping_note text,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (allocated_quantity IS NOT NULL OR allocated_value_usd IS NOT NULL OR allocation_stage='ADJUSTMENT')
);

CREATE UNIQUE INDEX uq_import_plan_allocation_active_source
ON trade.import_plan_allocation(source_entity_type,source_entity_id,allocation_stage)
WHERE status='ACTIVE';
CREATE INDEX idx_import_plan_allocation_plan_item
ON trade.import_plan_allocation(plan_item_id,allocation_stage,status);

CREATE TABLE trade.import_plan_mapping_rule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_plan_id uuid NOT NULL REFERENCES trade.import_plan(id) ON DELETE RESTRICT,
  plan_item_id uuid NOT NULL REFERENCES trade.import_plan_item(id) ON DELETE RESTRICT,
  product_id uuid,
  registration_id uuid,
  product_name_normalized text,
  category_code varchar(100),
  priority integer NOT NULL DEFAULT 100 CHECK(priority>=0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    product_id IS NOT NULL OR registration_id IS NOT NULL
    OR NULLIF(btrim(product_name_normalized),'') IS NOT NULL
    OR category_code IS NOT NULL
  )
);

CREATE INDEX idx_import_plan_mapping_rule_plan
ON trade.import_plan_mapping_rule(import_plan_id,is_active,priority);

-- Preserve current 000780 behavior for all existing data.
INSERT INTO trade.import_plan_profile(import_plan_id,detail_level)
SELECT id,'ITEM' FROM trade.import_plan;

INSERT INTO trade.import_plan_item_profile(plan_item_id,scope_type,tracking_basis)
SELECT id,'ITEM','QUANTITY' FROM trade.import_plan_item;

-- New extension rows are regulatory records: no hard delete.
CREATE TRIGGER trg_no_delete_import_plan_profile
BEFORE DELETE ON trade.import_plan_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_item_profile
BEFORE DELETE ON trade.import_plan_item_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_allocation
BEFORE DELETE ON trade.import_plan_allocation
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_import_plan_mapping_rule
BEFORE DELETE ON trade.import_plan_mapping_rule
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_import_plan_profile_updated_at
BEFORE UPDATE ON trade.import_plan_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_item_profile_updated_at
BEFORE UPDATE ON trade.import_plan_item_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_allocation_updated_at
BEFORE UPDATE ON trade.import_plan_allocation
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_import_plan_mapping_rule_updated_at
BEFORE UPDATE ON trade.import_plan_mapping_rule
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000800_vet_drug_registration_operational.sql
-- ============================================================================
-- LVSP 000800: Veterinary Drug Registration Operational Foundation
-- Date: 2026-08-13
--
-- PURPOSE
--   Complete the database-side operational foundation for veterinary drug
--   registration without replacing the existing product/product_regulatory_profile
--   model and without changing any previously-applied migration.
--
-- DESIGN
--   Product != Application/Case != Registration != Package/Presentation != Certificate.
--   Legacy registration data remains valid.
--   Regulatory state changes are command-driven through
--   registration.transition_veterinary_drug_application(...).
--   Legal fees, statutory deadlines, approval/signature authority, final official
--   certificate wording and other legal values are NOT hard-coded here.
--   Those remain PENDING_LEGAL_VERIFICATION / configurable.
--
-- NON-DESTRUCTIVE
--   No DROP TABLE.
--   No DELETE.
--   No automatic legacy-data rewrite.
--   New regulatory records use ON DELETE RESTRICT and hard-delete guards.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('product.product_regulatory_profile') IS NULL THEN
    missing := array_append(missing,'product.product_regulatory_profile');
  END IF;
  IF to_regclass('product.product') IS NULL THEN
    missing := array_append(missing,'product.product');
  END IF;
  IF to_regclass('product.product_version') IS NULL THEN
    missing := array_append(missing,'product.product_version');
  END IF;
  IF to_regclass('product.package') IS NULL THEN
    missing := array_append(missing,'product.package');
  END IF;
  IF to_regclass('product.package_version') IS NULL THEN
    missing := array_append(missing,'product.package_version');
  END IF;
  IF to_regclass('casework.regulatory_case') IS NULL THEN
    missing := array_append(missing,'casework.regulatory_case');
  END IF;
  IF to_regclass('workflow.instance') IS NULL THEN
    missing := array_append(missing,'workflow.instance');
  END IF;
  IF to_regclass('document.document') IS NULL THEN
    missing := array_append(missing,'document.document');
  END IF;
  IF to_regclass('document.certificate') IS NULL THEN
    missing := array_append(missing,'document.certificate');
  END IF;
  IF to_regclass('registration.registration') IS NULL THEN
    missing := array_append(missing,'registration.registration');
  END IF;
  IF to_regclass('registration.product_registration_package') IS NULL THEN
    missing := array_append(missing,'registration.product_registration_package');
  END IF;

  IF cardinality(missing) > 0 THEN
    RAISE EXCEPTION '000800 prerequisites missing: %', array_to_string(missing,', ');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Application / operational dossier
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Existing detailed drug profile remains the operational product dossier source.
  regulatory_profile_id UUID NOT NULL
    REFERENCES product.product_regulatory_profile(id) ON DELETE RESTRICT,
  product_id UUID NOT NULL
    REFERENCES product.product(id) ON DELETE RESTRICT,
  product_version_id UUID
    REFERENCES product.product_version(id) ON DELETE RESTRICT,

  -- Generic regulatory architecture links.
  case_id UUID
    REFERENCES casework.regulatory_case(id) ON DELETE RESTRICT,
  workflow_instance_id UUID
    REFERENCES workflow.instance(id) ON DELETE RESTRICT,

  -- Application identity. Existing legacy profiles are NOT auto-converted.
  application_no VARCHAR(120),
  application_date DATE,
  registration_type VARCHAR(40) NOT NULL DEFAULT 'IMPORT',

  -- Applicant can be a person or company via master.party.
  applicant_party_id UUID
    REFERENCES master.party(id) ON DELETE RESTRICT,
  applicant_site_id UUID
    REFERENCES master.facility(id) ON DELETE RESTRICT,

  -- Renewal / variation lineage.
  prior_registration_id UUID
    REFERENCES registration.registration(id) ON DELETE RESTRICT,
  application_kind VARCHAR(30) NOT NULL DEFAULT 'NEW'
    CHECK (application_kind IN ('NEW','RENEWAL','VARIATION','TRANSFER','LEGACY_MIGRATION')),

  -- Domain lifecycle. Changes are guarded and must use the command function below.
  current_status VARCHAR(40) NOT NULL DEFAULT 'DRAFT'
    CHECK (current_status IN (
      'DRAFT',
      'SUBMITTED',
      'SCREENING',
      'CORRECTION_REQUESTED',
      'RESUBMITTED',
      'TECHNICAL_REVIEW',
      'RECOMMENDED_APPROVAL',
      'RECOMMENDED_REJECTION',
      'APPROVED',
      'REJECTED',
      'REGISTERED',
      'CANCELLED',
      'LEGACY_IMPORTED'
    )),

  correction_round INTEGER NOT NULL DEFAULT 0 CHECK (correction_round >= 0),
  submitted_at TIMESTAMPTZ,
  screening_started_at TIMESTAMPTZ,
  technical_review_started_at TIMESTAMPTZ,
  recommended_at TIMESTAMPTZ,
  decided_at TIMESTAMPTZ,
  registered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,

  configuration_status VARCHAR(40) NOT NULL DEFAULT 'PENDING_LEGAL_VERIFICATION',
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(case_id),
  UNIQUE(workflow_instance_id),
  CONSTRAINT ck_vet_drug_app_no_not_blank
    CHECK (application_no IS NULL OR btrim(application_no) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_application_no
  ON registration.veterinary_drug_application(application_no)
  WHERE application_no IS NOT NULL;

-- A drug profile may have multiple lifecycle applications over time
-- (new registration, renewal, variation, transfer). Do not force 1 profile = 1 application.
CREATE INDEX IF NOT EXISTS idx_vet_drug_app_profile
  ON registration.veterinary_drug_application(regulatory_profile_id,created_at DESC);

CREATE INDEX IF NOT EXISTS idx_vet_drug_app_status
  ON registration.veterinary_drug_application(current_status,updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_vet_drug_app_product
  ON registration.veterinary_drug_application(product_id);
CREATE INDEX IF NOT EXISTS idx_vet_drug_app_applicant
  ON registration.veterinary_drug_application(applicant_party_id);
CREATE INDEX IF NOT EXISTS idx_vet_drug_app_prior_registration
  ON registration.veterinary_drug_application(prior_registration_id)
  WHERE prior_registration_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Role-specific parties/sites + regulatory snapshots
--    Search/select Company Master first in the UI; snapshots preserve official text.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application_party (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,

  role_code VARCHAR(40) NOT NULL
    CHECK (role_code IN (
      'APPLICANT',
      'REGISTRATION_HOLDER',
      'MAH',
      'IMPORTER',
      'MANUFACTURER',
      'DISTRIBUTOR',
      'AUTHORIZED_REPRESENTATIVE',
      'OTHER'
    )),

  party_id UUID
    REFERENCES master.party(id) ON DELETE RESTRICT,
  facility_id UUID
    REFERENCES master.facility(id) ON DELETE RESTRICT,

  name_snapshot TEXT,
  address_snapshot TEXT,
  country_snapshot TEXT,
  contact_snapshot TEXT,

  is_primary BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from DATE,
  valid_to DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE','SUPERSEDED','CANCELLED')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_app_party_dates
    CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from),
  CONSTRAINT ck_vet_drug_app_party_identity
    CHECK (
      party_id IS NOT NULL
      OR NULLIF(btrim(name_snapshot),'') IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_app_party_role
  ON registration.veterinary_drug_application_party(application_id,role_code,status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_app_primary_role
  ON registration.veterinary_drug_application_party(application_id,role_code)
  WHERE is_primary = TRUE AND status = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- 3. Application presentations
--    One product/registration may have multiple package/presentation records.
--    Each presentation can later receive its own sub-registration and certificate.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application_presentation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,
  package_id UUID NOT NULL
    REFERENCES product.package(id) ON DELETE RESTRICT,
  package_version_id UUID
    REFERENCES product.package_version(id) ON DELETE RESTRICT,

  sequence_no INTEGER NOT NULL CHECK (sequence_no > 0),
  requested_sub_code VARCHAR(30),
  proposed_registration_package_no VARCHAR(120),

  separate_certificate BOOLEAN NOT NULL DEFAULT TRUE,
  separate_qr BOOLEAN NOT NULL DEFAULT TRUE,

  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REGISTERED','SUPERSEDED','CANCELLED')),

  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(application_id,sequence_no),
  UNIQUE(application_id,package_id),
  CONSTRAINT ck_vet_drug_presentation_sub_code
    CHECK (requested_sub_code IS NULL OR btrim(requested_sub_code) <> '')
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_app_presentation
  ON registration.veterinary_drug_application_presentation(application_id,status);

-- ---------------------------------------------------------------------------
-- 4. Dossier / supporting evidence
--    Requirement codes stay configurable. We do NOT hard-code legal mandatory rules.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application_document (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,

  requirement_code VARCHAR(80) NOT NULL,
  requirement_label TEXT,
  document_id UUID
    REFERENCES document.document(id) ON DELETE RESTRICT,

  is_required BOOLEAN NOT NULL DEFAULT FALSE,
  requirement_source VARCHAR(40) NOT NULL DEFAULT 'PENDING_LEGAL_VERIFICATION',
  legal_reference TEXT,

  verification_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
    CHECK (verification_status IN (
      'PENDING','RECEIVED','ACCEPTED','REJECTED','WAIVED','NOT_APPLICABLE'
    )),
  checked_by UUID
    REFERENCES security.app_user(id) ON DELETE RESTRICT,
  checked_at TIMESTAMPTZ,
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_doc_code_not_blank CHECK (btrim(requirement_code) <> '')
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_app_document
  ON registration.veterinary_drug_application_document(application_id,requirement_code,verification_status);
CREATE INDEX IF NOT EXISTS idx_vet_drug_app_document_doc
  ON registration.veterinary_drug_application_document(document_id)
  WHERE document_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. Screening / technical review records
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_review (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,

  review_type VARCHAR(40) NOT NULL
    CHECK (review_type IN (
      'SCREENING',
      'TECHNICAL',
      'QUALITY',
      'SAFETY',
      'EFFICACY',
      'LABEL',
      'DOSSIER',
      'FINAL'
    )),
  review_round INTEGER NOT NULL DEFAULT 1 CHECK (review_round > 0),

  reviewer_user_id UUID
    REFERENCES security.app_user(id) ON DELETE RESTRICT,
  reviewer_role_code VARCHAR(100),

  outcome VARCHAR(40) NOT NULL DEFAULT 'PENDING'
    CHECK (outcome IN (
      'PENDING',
      'PASS',
      'FAIL',
      'NEEDS_CORRECTION',
      'RECOMMEND_APPROVAL',
      'RECOMMEND_REJECTION'
    )),

  findings TEXT,
  recommendation TEXT,
  internal_notes TEXT,

  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(application_id,review_type,review_round)
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_review_app
  ON registration.veterinary_drug_review(application_id,review_type,review_round);

-- ---------------------------------------------------------------------------
-- 6. Command-based lifecycle rules + immutable action history
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_transition_rule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_status VARCHAR(40) NOT NULL,
  action_code VARCHAR(60) NOT NULL,
  to_status VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  configuration_status VARCHAR(40) NOT NULL DEFAULT 'OPERATIONAL_BASELINE',
  notes TEXT,
  UNIQUE(from_status,action_code)
);

INSERT INTO registration.veterinary_drug_transition_rule
  (from_status,action_code,to_status,notes)
VALUES
  ('DRAFT','SUBMIT','SUBMITTED','Submit applicant dossier for review'),
  ('SUBMITTED','RETURN_TO_DRAFT','DRAFT','Administrative return before screening'),
  ('SUBMITTED','START_SCREENING','SCREENING','Begin completeness/administrative screening'),
  ('SCREENING','REQUEST_CORRECTION','CORRECTION_REQUESTED','Request missing/corrected information'),
  ('CORRECTION_REQUESTED','RESUBMIT','RESUBMITTED','Applicant submits correction'),
  ('RESUBMITTED','START_SCREENING','SCREENING','Re-screen corrected dossier'),
  ('RESUBMITTED','START_TECHNICAL_REVIEW','TECHNICAL_REVIEW','Proceed directly when re-screening is complete'),
  ('SCREENING','START_TECHNICAL_REVIEW','TECHNICAL_REVIEW','Begin technical assessment'),
  ('TECHNICAL_REVIEW','REQUEST_CORRECTION','CORRECTION_REQUESTED','Technical correction/request for information'),
  ('TECHNICAL_REVIEW','RECOMMEND_APPROVAL','RECOMMENDED_APPROVAL','Technical recommendation'),
  ('TECHNICAL_REVIEW','RECOMMEND_REJECTION','RECOMMENDED_REJECTION','Technical recommendation'),
  ('RECOMMENDED_APPROVAL','APPROVE','APPROVED','Competent approval action; authority configured outside this migration'),
  ('RECOMMENDED_REJECTION','REJECT','REJECTED','Competent rejection action; authority configured outside this migration'),
  ('APPROVED','REGISTER','REGISTERED','Create/link official registration before certificate issuance'),
  ('DRAFT','CANCEL','CANCELLED','Cancel draft'),
  ('SUBMITTED','CANCEL','CANCELLED','Cancel submitted application where permitted'),
  ('CORRECTION_REQUESTED','CANCEL','CANCELLED','Cancel correction cycle where permitted'),
  ('RESUBMITTED','CANCEL','CANCELLED','Cancel resubmission where permitted')
ON CONFLICT (from_status,action_code)
DO UPDATE SET
  to_status = EXCLUDED.to_status,
  notes = EXCLUDED.notes,
  is_active = TRUE;

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application_action (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,

  action_code VARCHAR(60) NOT NULL,
  from_status VARCHAR(40),
  to_status VARCHAR(40),

  actor_user_id UUID
    REFERENCES security.app_user(id) ON DELETE RESTRICT,
  comment TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  performed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_action_app_time
  ON registration.veterinary_drug_application_action(application_id,performed_at DESC);

CREATE OR REPLACE FUNCTION registration.guard_veterinary_drug_status_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.current_status IS DISTINCT FROM OLD.current_status
     AND COALESCE(current_setting('lvsp.vet_drug_transition',true),'') <> '1' THEN
    RAISE EXCEPTION
      'Veterinary drug application status must change through registration.transition_veterinary_drug_application()';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_vet_drug_status
  ON registration.veterinary_drug_application;
CREATE TRIGGER trg_guard_vet_drug_status
BEFORE UPDATE OF current_status
ON registration.veterinary_drug_application
FOR EACH ROW
EXECUTE FUNCTION registration.guard_veterinary_drug_status_update();

CREATE OR REPLACE FUNCTION registration.transition_veterinary_drug_application(
  p_application_id UUID,
  p_action_code VARCHAR,
  p_actor_user_id UUID DEFAULT NULL,
  p_comment TEXT DEFAULT NULL
)
RETURNS registration.veterinary_drug_application
LANGUAGE plpgsql
AS $$
DECLARE
  v_app registration.veterinary_drug_application%ROWTYPE;
  v_rule registration.veterinary_drug_transition_rule%ROWTYPE;
BEGIN
  SELECT *
    INTO v_app
    FROM registration.veterinary_drug_application
   WHERE id = p_application_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Veterinary drug application not found: %',p_application_id;
  END IF;

  SELECT *
    INTO v_rule
    FROM registration.veterinary_drug_transition_rule
   WHERE from_status = v_app.current_status
     AND action_code = upper(btrim(p_action_code))
     AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Action % is not allowed from status %',
      upper(btrim(p_action_code)),v_app.current_status;
  END IF;

  PERFORM set_config('lvsp.vet_drug_transition','1',true);

  UPDATE registration.veterinary_drug_application
     SET current_status = v_rule.to_status,
         correction_round = CASE
           WHEN v_rule.to_status = 'CORRECTION_REQUESTED'
             THEN correction_round + 1
           ELSE correction_round
         END,
         submitted_at = CASE
           WHEN v_rule.to_status IN ('SUBMITTED','RESUBMITTED')
             THEN COALESCE(submitted_at,now())
           ELSE submitted_at
         END,
         screening_started_at = CASE
           WHEN v_rule.to_status = 'SCREENING'
             THEN COALESCE(screening_started_at,now())
           ELSE screening_started_at
         END,
         technical_review_started_at = CASE
           WHEN v_rule.to_status = 'TECHNICAL_REVIEW'
             THEN COALESCE(technical_review_started_at,now())
           ELSE technical_review_started_at
         END,
         recommended_at = CASE
           WHEN v_rule.to_status IN ('RECOMMENDED_APPROVAL','RECOMMENDED_REJECTION')
             THEN now()
           ELSE recommended_at
         END,
         decided_at = CASE
           WHEN v_rule.to_status IN ('APPROVED','REJECTED')
             THEN now()
           ELSE decided_at
         END,
         registered_at = CASE
           WHEN v_rule.to_status = 'REGISTERED'
             THEN now()
           ELSE registered_at
         END,
         cancelled_at = CASE
           WHEN v_rule.to_status = 'CANCELLED'
             THEN now()
           ELSE cancelled_at
         END,
         updated_at = now()
   WHERE id = p_application_id
   RETURNING * INTO v_app;

  INSERT INTO registration.veterinary_drug_application_action(
    application_id,action_code,from_status,to_status,
    actor_user_id,comment,metadata
  )
  VALUES(
    p_application_id,
    upper(btrim(p_action_code)),
    v_rule.from_status,
    v_rule.to_status,
    p_actor_user_id,
    p_comment,
    jsonb_build_object(
      'configurationStatus',v_rule.configuration_status,
      'transitionRuleId',v_rule.id
    )
  );

  RETURN v_app;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. Final official registration linkage
--    Approval is not the same object as Registration.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_application_registration (
  application_id UUID PRIMARY KEY
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,
  registration_id UUID NOT NULL UNIQUE
    REFERENCES registration.registration(id) ON DELETE RESTRICT,

  linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  linked_by UUID
    REFERENCES security.app_user(id) ON DELETE RESTRICT,
  notes TEXT
);

-- Presentation -> official registration package.
CREATE TABLE IF NOT EXISTS registration.veterinary_drug_presentation_registration (
  application_presentation_id UUID PRIMARY KEY
    REFERENCES registration.veterinary_drug_application_presentation(id) ON DELETE RESTRICT,

  registration_id UUID NOT NULL,
  package_id UUID NOT NULL,

  linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  linked_by UUID
    REFERENCES security.app_user(id) ON DELETE RESTRICT,
  notes TEXT,

  UNIQUE(registration_id,package_id),

  CONSTRAINT fk_vet_drug_presentation_reg_package
    FOREIGN KEY(registration_id,package_id)
    REFERENCES registration.product_registration_package(registration_id,package_id)
    ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------------
-- 8. Presentation-specific certificate linkage
--    Registration != Certificate. Each package/presentation can have its own cert.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_presentation_certificate (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  application_presentation_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_application_presentation(id) ON DELETE RESTRICT,
  certificate_id UUID NOT NULL UNIQUE
    REFERENCES document.certificate(id) ON DELETE RESTRICT,

  registration_id UUID
    REFERENCES registration.registration(id) ON DELETE RESTRICT,
  package_id UUID
    REFERENCES product.package(id) ON DELETE RESTRICT,

  certificate_role VARCHAR(40) NOT NULL DEFAULT 'REGISTRATION_CERTIFICATE',
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('DRAFT','ACTIVE','SUPERSEDED','REVOKED')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(application_presentation_id,certificate_role)
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_pres_cert_registration
  ON registration.veterinary_drug_presentation_certificate(registration_id)
  WHERE registration_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 9. Data-integrity validation: product/version/package must belong together.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registration.validate_veterinary_drug_application_refs()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_profile_product UUID;
  v_version_product UUID;
BEGIN
  SELECT product_id INTO v_profile_product
    FROM product.product_regulatory_profile
   WHERE id = NEW.regulatory_profile_id;

  IF v_profile_product IS NULL OR v_profile_product <> NEW.product_id THEN
    RAISE EXCEPTION
      'regulatory_profile_id % does not belong to product_id %',
      NEW.regulatory_profile_id,NEW.product_id;
  END IF;

  IF NEW.product_version_id IS NOT NULL THEN
    SELECT product_id INTO v_version_product
      FROM product.product_version
     WHERE id = NEW.product_version_id;

    IF v_version_product IS NULL OR v_version_product <> NEW.product_id THEN
      RAISE EXCEPTION
        'product_version_id % does not belong to product_id %',
        NEW.product_version_id,NEW.product_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_vet_drug_application_refs
  ON registration.veterinary_drug_application;
CREATE TRIGGER trg_validate_vet_drug_application_refs
BEFORE INSERT OR UPDATE OF regulatory_profile_id,product_id,product_version_id
ON registration.veterinary_drug_application
FOR EACH ROW
EXECUTE FUNCTION registration.validate_veterinary_drug_application_refs();

CREATE OR REPLACE FUNCTION registration.validate_veterinary_drug_presentation_refs()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_product UUID;
  v_package_product UUID;
  v_package_version_package UUID;
BEGIN
  SELECT product_id INTO v_product
    FROM registration.veterinary_drug_application
   WHERE id = NEW.application_id;

  SELECT product_id INTO v_package_product
    FROM product.package
   WHERE id = NEW.package_id;

  IF v_product IS NULL OR v_package_product IS NULL OR v_product <> v_package_product THEN
    RAISE EXCEPTION
      'package_id % does not belong to the application product',
      NEW.package_id;
  END IF;

  IF NEW.package_version_id IS NOT NULL THEN
    SELECT package_id INTO v_package_version_package
      FROM product.package_version
     WHERE id = NEW.package_version_id;

    IF v_package_version_package IS NULL OR v_package_version_package <> NEW.package_id THEN
      RAISE EXCEPTION
        'package_version_id % does not belong to package_id %',
        NEW.package_version_id,NEW.package_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_vet_drug_presentation_refs
  ON registration.veterinary_drug_application_presentation;
CREATE TRIGGER trg_validate_vet_drug_presentation_refs
BEFORE INSERT OR UPDATE OF application_id,package_id,package_version_id
ON registration.veterinary_drug_application_presentation
FOR EACH ROW
EXECUTE FUNCTION registration.validate_veterinary_drug_presentation_refs();

-- ---------------------------------------------------------------------------
-- 10. Hard-delete guards / updated_at
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_application
  ON registration.veterinary_drug_application;
CREATE TRIGGER trg_no_delete_vet_drug_application
BEFORE DELETE ON registration.veterinary_drug_application
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_application_party
  ON registration.veterinary_drug_application_party;
CREATE TRIGGER trg_no_delete_vet_drug_application_party
BEFORE DELETE ON registration.veterinary_drug_application_party
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_application_presentation
  ON registration.veterinary_drug_application_presentation;
CREATE TRIGGER trg_no_delete_vet_drug_application_presentation
BEFORE DELETE ON registration.veterinary_drug_application_presentation
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_application_document
  ON registration.veterinary_drug_application_document;
CREATE TRIGGER trg_no_delete_vet_drug_application_document
BEFORE DELETE ON registration.veterinary_drug_application_document
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_review
  ON registration.veterinary_drug_review;
CREATE TRIGGER trg_no_delete_vet_drug_review
BEFORE DELETE ON registration.veterinary_drug_review
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_action
  ON registration.veterinary_drug_application_action;
CREATE TRIGGER trg_no_delete_vet_drug_action
BEFORE DELETE ON registration.veterinary_drug_application_action
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_app_registration
  ON registration.veterinary_drug_application_registration;
CREATE TRIGGER trg_no_delete_vet_drug_app_registration
BEFORE DELETE ON registration.veterinary_drug_application_registration
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_pres_registration
  ON registration.veterinary_drug_presentation_registration;
CREATE TRIGGER trg_no_delete_vet_drug_pres_registration
BEFORE DELETE ON registration.veterinary_drug_presentation_registration
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_pres_certificate
  ON registration.veterinary_drug_presentation_certificate;
CREATE TRIGGER trg_no_delete_vet_drug_pres_certificate
BEFORE DELETE ON registration.veterinary_drug_presentation_certificate
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_vet_drug_application_updated_at
  ON registration.veterinary_drug_application;
CREATE TRIGGER trg_vet_drug_application_updated_at
BEFORE UPDATE ON registration.veterinary_drug_application
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_vet_drug_application_party_updated_at
  ON registration.veterinary_drug_application_party;
CREATE TRIGGER trg_vet_drug_application_party_updated_at
BEFORE UPDATE ON registration.veterinary_drug_application_party
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_vet_drug_application_presentation_updated_at
  ON registration.veterinary_drug_application_presentation;
CREATE TRIGGER trg_vet_drug_application_presentation_updated_at
BEFORE UPDATE ON registration.veterinary_drug_application_presentation
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_vet_drug_application_document_updated_at
  ON registration.veterinary_drug_application_document;
CREATE TRIGGER trg_vet_drug_application_document_updated_at
BEFORE UPDATE ON registration.veterinary_drug_application_document
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ---------------------------------------------------------------------------
-- 11. Officer workspace view
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_veterinary_drug_registration_workspace AS
SELECT
  a.id AS application_id,
  a.application_no,
  a.application_date,
  a.application_kind,
  a.registration_type,
  a.current_status,
  a.configuration_status,
  a.correction_round,

  p.id AS product_id,
  p.trade_name,
  p.generic_name,

  pr.id AS regulatory_profile_id,
  pr.registration_no AS profile_registration_no,
  pr.dlf_no,
  pr.dlf_date,
  pr.issue_date,
  pr.expiry_date,
  pr.registration_status AS profile_registration_status,

  a.case_id,
  a.workflow_instance_id,
  a.prior_registration_id,

  COALESCE(pres.presentation_count,0) AS presentation_count,
  COALESCE(docs.document_count,0) AS dossier_document_count,
  COALESCE(docs.pending_document_count,0) AS pending_document_count,
  COALESCE(rev.review_count,0) AS review_count,
  COALESCE(rev.open_review_count,0) AS open_review_count,

  a.submitted_at,
  a.technical_review_started_at,
  a.decided_at,
  a.registered_at,
  a.updated_at
FROM registration.veterinary_drug_application a
JOIN product.product p ON p.id = a.product_id
JOIN product.product_regulatory_profile pr ON pr.id = a.regulatory_profile_id
LEFT JOIN LATERAL (
  SELECT count(*)::int AS presentation_count
  FROM registration.veterinary_drug_application_presentation x
  WHERE x.application_id = a.id
    AND x.status <> 'CANCELLED'
) pres ON TRUE
LEFT JOIN LATERAL (
  SELECT
    count(*)::int AS document_count,
    count(*) FILTER (
      WHERE x.is_required = TRUE
        AND x.verification_status NOT IN ('ACCEPTED','WAIVED','NOT_APPLICABLE')
    )::int AS pending_document_count
  FROM registration.veterinary_drug_application_document x
  WHERE x.application_id = a.id
) docs ON TRUE
LEFT JOIN LATERAL (
  SELECT
    count(*)::int AS review_count,
    count(*) FILTER (
      WHERE x.outcome = 'PENDING'
        AND x.completed_at IS NULL
    )::int AS open_review_count
  FROM registration.veterinary_drug_review x
  WHERE x.application_id = a.id
) rev ON TRUE;

COMMENT ON TABLE registration.veterinary_drug_application IS
'LVSP veterinary drug registration application/dossier lifecycle. Legal fees, deadlines, approval authority and final official certificate wording remain configurable / PENDING_LEGAL_VERIFICATION.';

COMMENT ON TABLE registration.veterinary_drug_application_presentation IS
'Application-level presentation/package selection. Supports one product -> many presentations, each capable of separate sub-registration, certificate and QR.';

COMMENT ON TABLE registration.veterinary_drug_application_document IS
'Application dossier/evidence links. Requirement codes and mandatory status are configuration-driven and must be legally verified before production enforcement.';

COMMENT ON FUNCTION registration.transition_veterinary_drug_application(UUID,VARCHAR,UUID,TEXT) IS
'Command transition for veterinary drug applications. API/domain service must use this instead of arbitrary status PATCH.';

-- ============================================================================
-- MIGRATION: 000810_legacy_registration_trade_parity.sql
-- ============================================================================
-- LVSP 000810: Legacy Registration + Trade Parity Pack
-- Date: 2026-08-14
--
-- PURPOSE
--   Preserve high-value operational functions from the legacy Veterinary System
--   inside the existing LVSP PostgreSQL architecture. This migration is additive.
--
-- SCOPE
--   1) One internal registration memo -> many veterinary drug registrations.
--      One product stays one memo row; selected package/presentation sub-registrations
--      are grouped inside that row and snapshotted for official history.
--   2) Import/export/transit coordination review checklist with the legacy IET
--      document-presence / document-quality review behaviour.
--   3) Stable analytics views for the shared regulatory report builder.
--
-- NON-DESTRUCTIVE
--   No DROP TABLE. No DELETE. Existing issued records are not rewritten.
--   Snapshots are intentionally JSONB because they are issued-document history.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('product.product_regulatory_profile') IS NULL THEN
    missing := array_append(missing,'product.product_regulatory_profile');
  END IF;
  IF to_regclass('product.package') IS NULL THEN
    missing := array_append(missing,'product.package');
  END IF;
  IF to_regclass('trade.import_application') IS NULL THEN
    missing := array_append(missing,'trade.import_application');
  END IF;
  IF to_regclass('trade.import_application_item') IS NULL THEN
    missing := array_append(missing,'trade.import_application_item');
  END IF;
  IF to_regclass('security.app_user') IS NULL THEN
    missing := array_append(missing,'security.app_user');
  END IF;
  IF cardinality(missing) > 0 THEN
    RAISE EXCEPTION '000810 prerequisites missing: %', array_to_string(missing,', ');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. Internal registration memo / cover sheet
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_internal_memo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_no VARCHAR(120),
  memo_suffix VARCHAR(40) NOT NULL DEFAULT 'ພສວພ',
  memo_date DATE NOT NULL DEFAULT current_date,
  place_text TEXT NOT NULL DEFAULT 'ນະຄອນຫຼວງວຽງຈັນ',

  organization_name TEXT NOT NULL DEFAULT 'ກົມລ້ຽງສັດ ແລະ ການປະມົງ',
  department_name TEXT NOT NULL DEFAULT 'ພະແນກສັດຕະວະແພດ',
  recipient TEXT NOT NULL DEFAULT 'ຫົວໜ້າກົມລ້ຽງສັດ ແລະ ການປະມົງ',
  subject_text TEXT,
  lead_text TEXT,

  purposes JSONB NOT NULL DEFAULT '["approve"]'::jsonb,
  company_auto BOOLEAN NOT NULL DEFAULT TRUE,
  group_by_company BOOLEAN NOT NULL DEFAULT TRUE,
  show_lao BOOLEAN NOT NULL DEFAULT TRUE,
  show_sub_registration BOOLEAN NOT NULL DEFAULT TRUE,
  show_pack BOOLEAN NOT NULL DEFAULT TRUE,
  show_category BOOLEAN NOT NULL DEFAULT TRUE,

  staff_lines JSONB NOT NULL DEFAULT '[]'::jsonb,
  signatory_names JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,

  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT','READY','SIGNED','ARCHIVED','CANCELLED')),
  created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_internal_memo_purposes_array
    CHECK (jsonb_typeof(purposes) = 'array'),
  CONSTRAINT ck_vet_drug_internal_memo_staff_array
    CHECK (jsonb_typeof(staff_lines) = 'array'),
  CONSTRAINT ck_vet_drug_internal_memo_signatories_object
    CHECK (jsonb_typeof(signatory_names) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_vet_drug_internal_memo_date
  ON registration.veterinary_drug_internal_memo(memo_date DESC,status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_internal_memo_no
  ON registration.veterinary_drug_internal_memo(memo_no,memo_suffix)
  WHERE memo_no IS NOT NULL AND btrim(memo_no) <> '' AND status <> 'CANCELLED';

CREATE TABLE IF NOT EXISTS registration.veterinary_drug_internal_memo_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id UUID NOT NULL
    REFERENCES registration.veterinary_drug_internal_memo(id) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK (sequence_no > 0),

  regulatory_profile_id UUID NOT NULL
    REFERENCES product.product_regulatory_profile(id) ON DELETE RESTRICT,
  application_id UUID
    REFERENCES registration.veterinary_drug_application(id) ON DELETE RESTRICT,
  registration_id UUID
    REFERENCES registration.registration(id) ON DELETE RESTRICT,

  registration_no_snapshot TEXT,
  trade_name_snapshot TEXT NOT NULL,
  generic_name_snapshot TEXT,
  category_snapshot TEXT,
  dosage_form_snapshot TEXT,
  holder_snapshot TEXT,
  manufacturer_snapshot TEXT,
  selected_presentations JSONB NOT NULL DEFAULT '[]'::jsonb,
  source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,

  record_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK (record_status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_vet_drug_memo_item_presentations_array
    CHECK (jsonb_typeof(selected_presentations) = 'array'),
  CONSTRAINT ck_vet_drug_memo_item_source_object
    CHECK (jsonb_typeof(source_snapshot) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_memo_item_active_sequence
  ON registration.veterinary_drug_internal_memo_item(memo_id,sequence_no)
  WHERE record_status='ACTIVE';
CREATE UNIQUE INDEX IF NOT EXISTS uq_vet_drug_memo_item_active_profile
  ON registration.veterinary_drug_internal_memo_item(memo_id,regulatory_profile_id)
  WHERE record_status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_vet_drug_memo_item_profile
  ON registration.veterinary_drug_internal_memo_item(regulatory_profile_id,created_at DESC);

-- ---------------------------------------------------------------------------
-- 2. Trade coordination / document review sheet
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lookup.regulatory_coordination_requirement (
  requirement_code VARCHAR(80) PRIMARY KEY,
  scope_code VARCHAR(60) NOT NULL,
  sequence_no INTEGER NOT NULL CHECK(sequence_no > 0),
  label_lo TEXT NOT NULL,
  label_en TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  configuration_status VARCHAR(40) NOT NULL DEFAULT 'LEGACY_OPERATIONAL_REFERENCE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(scope_code,sequence_no)
);

INSERT INTO lookup.regulatory_coordination_requirement
(requirement_code,scope_code,sequence_no,label_lo,label_en)
VALUES
('IET_APPLICATION_FORM','VET_DRUG_DEVICE_TRADE',1,'ໃບຄຳຮ້ອງ / ແບບຟອມ (IET 1 / IET 4)','Application / form (IET 1 / IET 4)'),
('ORIGIN_EXPORT_PERMIT','VET_DRUG_DEVICE_TRADE',2,'ໃບອະນຸຍາດສົ່ງອອກຈາກປະເທດຕົ້ນທາງ','Export permit from country of origin'),
('ANALYSIS_REPORT','VET_DRUG_DEVICE_TRADE',3,'ບົດວິໄຈ ແລະ ບົດລາຍງານ (IET 2 / IET 3)','Analysis / report (IET 2 / IET 3)'),
('INVOICE_PACKING_LIST','VET_DRUG_DEVICE_TRADE',4,'ໃບຢັ້ງຢືນລາຍການສິນຄ້າ (Invoice & Packing list)','Invoice & Packing list'),
('GMP_HACCP','VET_DRUG_DEVICE_TRADE',5,'ໃບຢັ້ງຢືນມາດຕະຖານການຜະລິດ (GMP / HACCP)','GMP / HACCP certificate'),
('HEALTH_QUALITY_CERT','VET_DRUG_DEVICE_TRADE',6,'ໃບຢັ້ງຢືນສຸຂະພາບສັດ / ຄຸນນະພາບສິນຄ້າ','Animal health / product quality certificate'),
('PRODUCT_REGISTRATION','VET_DRUG_DEVICE_TRADE',7,'ໃບຂຶ້ນທະບຽນຢາ / ຜະລິດຕະພັນ (ຖ້າມີ)','Drug / product registration (if applicable)'),
('OTHER_DOCUMENTS','VET_DRUG_DEVICE_TRADE',8,'ເອກະສານອື່ນໆ (ຖ້າມີ)','Other documents (if applicable)')
ON CONFLICT (requirement_code) DO UPDATE SET
  scope_code=EXCLUDED.scope_code,
  sequence_no=EXCLUDED.sequence_no,
  label_lo=EXCLUDED.label_lo,
  label_en=EXCLUDED.label_en,
  is_active=TRUE,
  updated_at=now();

CREATE TABLE IF NOT EXISTS trade.application_coordination_sheet (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL UNIQUE
    REFERENCES trade.import_application(id) ON DELETE RESTRICT,
  sheet_no VARCHAR(120),
  sheet_date DATE NOT NULL DEFAULT current_date,
  subject_text TEXT,
  overall_comment TEXT,
  reviewer_name TEXT,
  reviewer_position TEXT,
  head_section_name TEXT,
  deputy_director_comment TEXT,
  signatory_names JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(status IN ('DRAFT','REVIEWED','READY','SIGNED','ARCHIVED','CANCELLED')),
  created_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  updated_by UUID REFERENCES security.app_user(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_trade_coord_signatories_object CHECK(jsonb_typeof(signatory_names)='object')
);

CREATE INDEX IF NOT EXISTS idx_trade_coord_sheet_status
  ON trade.application_coordination_sheet(status,sheet_date DESC);

CREATE TABLE IF NOT EXISTS trade.application_coordination_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheet_id UUID NOT NULL
    REFERENCES trade.application_coordination_sheet(id) ON DELETE RESTRICT,
  requirement_code VARCHAR(80) NOT NULL
    REFERENCES lookup.regulatory_coordination_requirement(requirement_code) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK(sequence_no > 0),
  label_snapshot TEXT NOT NULL,
  presence_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
    CHECK(presence_status IN ('PENDING','PRESENT','MISSING','NOT_APPLICABLE')),
  quality_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
    CHECK(quality_status IN ('PENDING','CORRECT','INCORRECT','POLICY','NOT_APPLICABLE')),
  reference_no TEXT,
  notes TEXT,
  document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT,
  record_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'
    CHECK(record_status IN ('ACTIVE','SUPERSEDED','CANCELLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_trade_coord_item_active_requirement
  ON trade.application_coordination_item(sheet_id,requirement_code)
  WHERE record_status='ACTIVE';
CREATE INDEX IF NOT EXISTS idx_trade_coord_item_sheet
  ON trade.application_coordination_item(sheet_id,sequence_no,record_status);

-- ---------------------------------------------------------------------------
-- 3. Shared Regulatory Report Builder views
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_veterinary_drug_registry_report AS
SELECT
  pr.id AS regulatory_profile_id,
  pr.product_id,
  pr.registration_no,
  pr.dlf_no,
  pr.dlf_date,
  pr.application_date,
  pr.issue_date,
  pr.expiry_date,
  pr.trade_name,
  pr.generic_name,
  pr.active_ingredients,
  pr.category,
  pr.dosage_form,
  pr.registration_type,
  COALESCE(h.legal_name_lo,h.legal_name_en) AS registration_holder,
  COALESCE(i.legal_name_lo,i.legal_name_en) AS importer,
  pr.manufacturer_name,
  pr.manufacturer_country,
  pr.valid_years,
  pr.registration_status,
  COALESCE(pkg.presentation_count,0) AS presentation_count,
  pr.created_at,
  pr.updated_at
FROM product.product_regulatory_profile pr
LEFT JOIN master.company h ON h.party_id=pr.holder_company_id
LEFT JOIN master.company i ON i.party_id=pr.importer_company_id
LEFT JOIN LATERAL (
  SELECT count(*)::int AS presentation_count
  FROM product.package p
  WHERE p.product_id=pr.product_id
    AND COALESCE(p.presentation_status,'ACTIVE')<>'INACTIVE'
) pkg ON TRUE;

CREATE OR REPLACE VIEW analytics.v_veterinary_trade_permit_report AS
SELECT
  ia.id AS application_id,
  ia.application_no,
  ia.permit_no,
  ia.import_type AS movement_type,
  ia.application_date,
  ia.decision_date,
  ia.cleared_date,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS operator_name,
  ia.origin_country,
  ia.destination_country,
  ia.border_checkpoint,
  ia.checkpoint_out,
  ia.transport_mode,
  COUNT(i.id)::int AS item_count,
  COALESCE(SUM(i.requested_quantity),0) AS requested_quantity,
  COALESCE(SUM(COALESCE(i.cleared_packs,i.cleared_quantity,0)),0) AS total_packs,
  COALESCE(SUM(i.item_value),0) AS total_value,
  COALESCE(SUM(i.active_substance_kg),0) AS amr_kg,
  ia.status,
  ia.created_at,
  ia.updated_at
FROM trade.import_application ia
LEFT JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_application_item i ON i.application_id=ia.id
GROUP BY
  ia.id,ia.application_no,ia.permit_no,ia.import_type,ia.application_date,
  ia.decision_date,ia.cleared_date,c.legal_name_lo,c.legal_name_en,
  ia.origin_country,ia.destination_country,ia.border_checkpoint,ia.checkpoint_out,
  ia.transport_mode,ia.status,ia.created_at,ia.updated_at;

-- ---------------------------------------------------------------------------
-- 4. Regulatory hard-delete guards and updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_vet_drug_internal_memo_updated_at
  ON registration.veterinary_drug_internal_memo;
CREATE TRIGGER trg_vet_drug_internal_memo_updated_at
BEFORE UPDATE ON registration.veterinary_drug_internal_memo
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_vet_drug_internal_memo_item_updated_at
  ON registration.veterinary_drug_internal_memo_item;
CREATE TRIGGER trg_vet_drug_internal_memo_item_updated_at
BEFORE UPDATE ON registration.veterinary_drug_internal_memo_item
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_coord_requirement_updated_at
  ON lookup.regulatory_coordination_requirement;
CREATE TRIGGER trg_coord_requirement_updated_at
BEFORE UPDATE ON lookup.regulatory_coordination_requirement
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_trade_coord_sheet_updated_at
  ON trade.application_coordination_sheet;
CREATE TRIGGER trg_trade_coord_sheet_updated_at
BEFORE UPDATE ON trade.application_coordination_sheet
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_trade_coord_item_updated_at
  ON trade.application_coordination_item;
CREATE TRIGGER trg_trade_coord_item_updated_at
BEFORE UPDATE ON trade.application_coordination_item
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_internal_memo
  ON registration.veterinary_drug_internal_memo;
CREATE TRIGGER trg_no_delete_vet_drug_internal_memo
BEFORE DELETE ON registration.veterinary_drug_internal_memo
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_vet_drug_internal_memo_item
  ON registration.veterinary_drug_internal_memo_item;
CREATE TRIGGER trg_no_delete_vet_drug_internal_memo_item
BEFORE DELETE ON registration.veterinary_drug_internal_memo_item
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_coord_requirement
  ON lookup.regulatory_coordination_requirement;
CREATE TRIGGER trg_no_delete_coord_requirement
BEFORE DELETE ON lookup.regulatory_coordination_requirement
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_trade_coord_sheet
  ON trade.application_coordination_sheet;
CREATE TRIGGER trg_no_delete_trade_coord_sheet
BEFORE DELETE ON trade.application_coordination_sheet
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_no_delete_trade_coord_item
  ON trade.application_coordination_item;
CREATE TRIGGER trg_no_delete_trade_coord_item
BEFORE DELETE ON trade.application_coordination_item
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE registration.veterinary_drug_internal_memo IS
'One official/internal coordination memo may cover many veterinary drug registrations. It is a cover/acknowledgement sheet, not the registration certificate itself.';
COMMENT ON TABLE registration.veterinary_drug_internal_memo_item IS
'One memo row per product/registration profile. Selected package/presentation sub-registrations are grouped and snapshotted inside selected_presentations.';
COMMENT ON TABLE trade.application_coordination_sheet IS
'Persistent LVSP version of the legacy import/export/transit coordination review sheet for veterinary drugs/devices.';
COMMENT ON VIEW analytics.v_veterinary_drug_registry_report IS
'Stable source for the shared regulatory report builder: veterinary drug registration.';
COMMENT ON VIEW analytics.v_veterinary_trade_permit_report IS
'Stable source for the shared regulatory report builder: veterinary trade applications/permits.';

-- ============================================================================
-- MIGRATION: 000820_online_auth_public_access.sql
-- ============================================================================
-- LVSP v1.7 Phase 2
-- Individual database authentication + controlled role metadata.
-- Safe additive migration: no existing regulatory/trade data is changed.

ALTER TABLE security.app_user
  ADD COLUMN IF NOT EXISTS password_hash TEXT,
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS failed_login_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='ck_app_user_failed_login_count'
      AND conrelid='security.app_user'::regclass
  ) THEN
    ALTER TABLE security.app_user
      ADD CONSTRAINT ck_app_user_failed_login_count CHECK(failed_login_count>=0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_user_status
  ON security.app_user(status);

CREATE INDEX IF NOT EXISTS idx_app_user_locked_until
  ON security.app_user(locked_until)
  WHERE locked_until IS NOT NULL;

INSERT INTO security.role(code,name_lo,name_en,is_system_role,is_active) VALUES
  ('SYSTEM_ADMIN','ຜູ້ບໍລິຫານລະບົບ','System Administrator',TRUE,TRUE),
  ('SECURITY_ADMIN','ຜູ້ຄຸ້ມຄອງສິດຜູ້ໃຊ້','Security Administrator',TRUE,TRUE),
  ('DATA_STEWARD','ຜູ້ຄຸ້ມຄອງຂໍ້ມູນກາງ','Data Steward',TRUE,TRUE),
  ('REGISTRY_OFFICER','ພະນັກງານທະບຽນ','Registry Officer',TRUE,TRUE),
  ('TECHNICAL_REVIEWER','ພະນັກງານກວດດ້ານວິຊາການ','Technical Reviewer',TRUE,TRUE),
  ('APPROVING_AUTHORITY','ຜູ້ມີອຳນາດອະນຸມັດ','Approving Authority',TRUE,TRUE),
  ('BORDER_OFFICER','ພະນັກງານດ່ານ','Border Officer',TRUE,TRUE),
  ('QUARANTINE_OFFICER','ພະນັກງານກັກກັນ','Quarantine Officer',TRUE,TRUE),
  ('MANAGEMENT_VIEWER','ຜູ້ບໍລິຫານເບິ່ງລາຍງານ','Management Viewer',TRUE,TRUE)
ON CONFLICT(code) DO UPDATE SET
  name_lo=EXCLUDED.name_lo,
  name_en=EXCLUDED.name_en,
  is_active=TRUE;

INSERT INTO security.permission(code,description) VALUES
  ('public.read','Read public LVSP information'),
  ('veterinary_drug.read','Read veterinary drug registration data'),
  ('veterinary_drug.write','Create/update veterinary drug registration working data'),
  ('veterinary_drug.review','Review veterinary drug dossiers'),
  ('veterinary_drug.approve','Approve veterinary drug regulatory decisions'),
  ('trade.read','Read import/export/transit data'),
  ('trade.write','Create/update import/export/transit working data'),
  ('trade.review','Review import/export/transit applications'),
  ('trade.approve','Approve import/export/transit decisions'),
  ('master_data.read','Read shared master data'),
  ('master_data.write','Maintain shared master data'),
  ('report.read','Read regulatory/management reports'),
  ('security.user.manage','Manage LVSP user accounts and roles')
ON CONFLICT(code) DO NOTHING;

-- SYSTEM_ADMIN gets every permission.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

-- SECURITY_ADMIN controls identity/role administration.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('security.user.manage','public.read','report.read')
WHERE r.code='SECURITY_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.write','trade.read')
WHERE r.code='REGISTRY_OFFICER'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.review','trade.read','trade.review','report.read')
WHERE r.code='TECHNICAL_REVIEWER'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','veterinary_drug.approve','trade.read','trade.approve','report.read')
WHERE r.code='APPROVING_AUTHORITY'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','trade.read','trade.write')
WHERE r.code IN ('BORDER_OFFICER','QUARANTINE_OFFICER')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','master_data.read','master_data.write')
WHERE r.code='DATA_STEWARD'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('public.read','veterinary_drug.read','trade.read','master_data.read','report.read')
WHERE r.code='MANAGEMENT_VIEWER'
ON CONFLICT DO NOTHING;

COMMENT ON COLUMN security.app_user.password_hash IS
'LVSP application password verifier. Never expose via API or frontend.';
COMMENT ON COLUMN security.app_user.must_change_password IS
'Forces a newly provisioned/reset account to set a personal password before normal work.';

-- ============================================================================
-- MIGRATION: 000830_national_access_foundation.sql
-- ============================================================================
-- LVSP v1.8 — National Access Foundation
-- Additive foundation for Central → Province → District → Checkpoint rollout,
-- public module roadmap/catalog, scoped staff assignments, and establishment licensing policy metadata.
-- This migration does NOT assign legal issuing authority. Authority rules remain DRAFT until formally approved.

CREATE TABLE IF NOT EXISTS system.module_catalog (
  module_code VARCHAR(100) PRIMARY KEY,
  module_key VARCHAR(100) UNIQUE,
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  description_lo TEXT,
  description_en TEXT,
  icon VARCHAR(20),
  delivery_status VARCHAR(30) NOT NULL DEFAULT 'PLANNED'
    CHECK(delivery_status IN ('ACTIVE','IN_DEVELOPMENT','PLANNED','PAUSED','RETIRED')),
  public_visible BOOLEAN NOT NULL DEFAULT TRUE,
  login_required BOOLEAN NOT NULL DEFAULT TRUE,
  public_data_mode VARCHAR(30) NOT NULL DEFAULT 'CATALOG_ONLY'
    CHECK(public_data_mode IN ('NONE','CATALOG_ONLY','READ_ONLY')),
  display_order INTEGER NOT NULL DEFAULT 1000,
  status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_module_catalog_public
  ON system.module_catalog(public_visible,delivery_status,display_order);
DROP TRIGGER IF EXISTS trg_module_catalog_updated_at ON system.module_catalog;
CREATE TRIGGER trg_module_catalog_updated_at
  BEFORE UPDATE ON system.module_catalog
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

INSERT INTO system.module_catalog(module_code,module_key,name_lo,name_en,description_lo,description_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order) VALUES
('VET_DRUG_REGISTRATION','drug_registrations','ຂຶ້ນທະບຽນຢາສັດ','Veterinary Drug Registration','ທະບຽນຢາສັດ ແລະ ການກວດສອບສະຖານະທະບຽນ','Veterinary drug registration and public registry','💊','ACTIVE',TRUE,TRUE,'READ_ONLY',10),
('VET_DRUG_TRADE','trade_workspace','ນຳເຂົ້າ · ສົ່ງອອກ · ສົ່ງຜ່ານ','Import · Export · Transit','ຄຳຮ້ອງ ໃບອະນຸມັດ ການຜ່ານດ່ານ ແລະ ANIMUSE','Applications, permits, border clearance and ANIMUSE','🚚','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',20),
('CENTRAL_REPORTS','regulatory_reports','ສູນລາຍງານ','Central Reports','ລາຍງານກຳກັບດູແລ ແລະ ສະຖິຕິກາງ','Central regulatory reports and statistics','📈','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',30),
('COMPANY_MASTER','companies','ບໍລິສັດ / ຜູ້ປະກອບການ','Companies & Operators','ທະບຽນຜູ້ປະກອບການກາງ','Shared operator registry','🏢','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',40),
('PRODUCT_MASTER','products','ຖານຂໍ້ມູນຜະລິດຕະພັນ','Product Master','ຂໍ້ມູນຜະລິດຕະພັນກາງທີ່ໃຊ້ຮ່ວມກັນ','Shared product master data','🧬','ACTIVE',TRUE,TRUE,'CATALOG_ONLY',50),
('ESTABLISHMENT_LICENSING','establishment_licensing','ອະນຸຍາດຮ້ານຢາ ແລະ ສະຖານປິ່ນປົວສັດ','Veterinary Establishment Licensing','ຮ້ານຂາຍຢາ/ອຸປະກອນສັດ ຫ້ອງປິ່ນປົວ ຄລີນິກ ແລະ ໂຮງໝໍສັດ','Veterinary pharmacies, treatment rooms, clinics and hospitals','🏥','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',60),
('BORDER_CLEARANCE','trade_shipments','ວຽກດ່ານ ແລະ ການກວດປ່ອຍ','Checkpoint & Border Clearance','ກວດໃບອະນຸຍາດ QR ການກວດທາງກາຍະພາບ ແລະ ບັນທຶກປະລິມານຈິງ','Permit verification, inspection and actual clearance records','🛂','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',70),
('INSPECTION','inspections','ການກວດກາ','Inspection & Compliance','ການກວດສະຖານທີ່ ການກວດຕິດຕາມ ແລະ compliance','Facility inspection, follow-up and compliance','🔎','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',80),
('VETERINARY_DEVICES','veterinary_devices','ອຸປະກອນສັດຕະວະແພດ','Veterinary Devices','ການຂຶ້ນທະບຽນ/ຄຸ້ມຄອງອຸປະກອນສັດຕະວະແພດ','Veterinary device registration and control','🩺','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',90),
('LABORATORY','laboratory_samples','ຫ້ອງວິໄຈ','Laboratory / LIMS','ຮັບຕົວຢ່າງ ກວດ ແລະ ລາຍງານຜົນ','Sample intake, testing and results','🧪','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',100),
('DISEASE_SURVEILLANCE','disease_cases','ເຝົ້າລະວັງພະຍາດ','Disease Surveillance','ລາຍງານເຫດສົງໄສ ການສືບສວນ ແລະ ຕິດຕາມພະຍາດ','Suspect reports, investigation and disease follow-up','🦠','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',110),
('GIS','gis_layers','ແຜນທີ່ GIS','GIS','ແຜນທີ່ສະຖານທີ່ ດ່ານ ຟາມ ແລະ ຂໍ້ມູນວິເຄາະ','Maps for facilities, checkpoints, farms and analysis','🗺️','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',120),
('ANIMAL_FEED_TRADE','animal_feed_trade','ອາຫານສັດ ແລະ ວັດຖຸດິບ','Animal Feed & Ingredients','ນຳເຂົ້າ ສົ່ງອອກ ສົ່ງຜ່ານ ແລະ ການອະນຸຍາດອາຫານສັດ','Feed and ingredient import, export, transit and licensing','🌾','PLANNED',TRUE,TRUE,'CATALOG_ONLY',200),
('ANIMAL_PRODUCT_TRADE','animal_product_trade','ສັດ ແລະ ຜະລິດຕະພັນສັດ','Animals & Animal Products','ນຳເຂົ້າ ສົ່ງອອກ ສົ່ງຜ່ານ ແລະ health certificate','Animal/product trade permits and health certificates','🐄','PLANNED',TRUE,TRUE,'CATALOG_ONLY',210),
('FARM_REGISTRATION','farm_registration','ຂຶ້ນທະບຽນຟາມ','Farm Registration','ທະບຽນຟາມ ຜູ້ລ້ຽງ ສະຖານທີ່ ແລະ ການຮັບຮອງ','Farm, operator and certification registry','🏡','PLANNED',TRUE,TRUE,'CATALOG_ONLY',220),
('SLAUGHTERHOUSE','slaughterhouse','ໂຮງຂ້າສັດ','Slaughterhouse','ທະບຽນ ອະນຸຍາດ ແລະ ກວດກາໂຮງຂ້າສັດ','Slaughterhouse registration, licensing and inspection','🏭','PLANNED',TRUE,TRUE,'CATALOG_ONLY',230),
('WET_MARKET','wet_market','ຕະຫຼາດສັດ/ຜະລິດຕະພັນ','Animal & Wet Markets','ທະບຽນ ກວດກາ ແລະ ຄຸ້ມຄອງຕະຫຼາດ','Market registration, inspection and monitoring','🏪','PLANNED',TRUE,TRUE,'CATALOG_ONLY',240),
('COMPLAINTS_GUIDANCE','complaints_guidance','ຄຳຮ້ອງ ຄຳແນະນຳ ແລະ ສອບຖາມ','Complaints, Guidance & Requests','ຮັບຄຳຮ້ອງ ສອບຖາມ ແລະ ຄູ່ມືບໍລິການ','Complaints, inquiries and service guidance','💬','PLANNED',TRUE,FALSE,'CATALOG_ONLY',250)
ON CONFLICT(module_code) DO NOTHING;

ALTER TABLE security.access_scope
  ADD COLUMN IF NOT EXISTS scope_name TEXT,
  ADD COLUMN IF NOT EXISTS scope_type VARCHAR(30) NOT NULL DEFAULT 'CUSTOM',
  ADD COLUMN IF NOT EXISTS facility_id UUID REFERENCES master.facility(id) ON DELETE RESTRICT;

ALTER TABLE security.access_scope DROP CONSTRAINT IF EXISTS ck_scope_target;
ALTER TABLE security.access_scope
  ADD CONSTRAINT ck_scope_target CHECK(
    is_global OR organization_id IS NOT NULL OR admin_unit_id IS NOT NULL OR facility_id IS NOT NULL OR domain_code IS NOT NULL
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='ck_access_scope_type' AND conrelid='security.access_scope'::regclass
  ) THEN
    ALTER TABLE security.access_scope ADD CONSTRAINT ck_access_scope_type CHECK(
      scope_type IN ('GLOBAL','CENTRAL','PROVINCE','DISTRICT','CHECKPOINT','ORGANIZATION','DOMAIN','CUSTOM')
    );
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_access_scope_admin_unit ON security.access_scope(admin_unit_id);
CREATE INDEX IF NOT EXISTS idx_access_scope_organization ON security.access_scope(organization_id);
CREATE INDEX IF NOT EXISTS idx_access_scope_facility ON security.access_scope(facility_id);

INSERT INTO security.role(code,name_lo,name_en,is_system_role,is_active) VALUES
('PROVINCIAL_ADMIN','ຜູ້ຄຸ້ມຄອງລະບົບລະດັບແຂວງ','Provincial Administrator',TRUE,TRUE),
('PROVINCIAL_LICENSING_OFFICER','ພະນັກງານອະນຸຍາດລະດັບແຂວງ','Provincial Licensing Officer',TRUE,TRUE),
('DISTRICT_LICENSING_OFFICER','ພະນັກງານອະນຸຍາດລະດັບເມືອງ','District Licensing Officer',TRUE,TRUE),
('DISTRICT_INSPECTOR','ພະນັກງານກວດກາລະດັບເມືອງ','District Inspector',TRUE,TRUE),
('CHECKPOINT_SUPERVISOR','ຫົວໜ້າ/ຜູ້ກວດກາດ່ານ','Checkpoint Supervisor',TRUE,TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO security.permission(code,description) VALUES
('security.scope.manage','Manage organization/geographic/checkpoint access scopes'),
('establishment.read','Read veterinary establishment licensing data'),
('establishment.write','Create/update establishment applications and working records'),
('establishment.inspect','Record establishment site inspections'),
('establishment.review','Review establishment licensing applications'),
('establishment.approve','Approve establishment licensing decisions where legally delegated'),
('checkpoint.read','Read checkpoint-bound permits and shipment records'),
('checkpoint.clear','Record border clearance/release actions'),
('checkpoint.hold','Record border hold/rejection actions'),
('module.catalog.manage','Manage public module roadmap/catalog')
ON CONFLICT(code) DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect','establishment.review','establishment.approve','report.read')
WHERE r.code='PROVINCIAL_ADMIN' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect','establishment.review','report.read')
WHERE r.code='PROVINCIAL_LICENSING_OFFICER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.write','establishment.inspect')
WHERE r.code='DISTRICT_LICENSING_OFFICER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','establishment.read','establishment.inspect')
WHERE r.code='DISTRICT_INSPECTOR' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN
('public.read','trade.read','trade.write','checkpoint.read','checkpoint.clear','checkpoint.hold')
WHERE r.code IN ('BORDER_OFFICER','QUARANTINE_OFFICER','CHECKPOINT_SUPERVISOR')
ON CONFLICT DO NOTHING;

INSERT INTO lookup.facility_type(code,name_lo,name_en,is_active) VALUES
('BORDER_CHECKPOINT','ດ່ານກວດກາສັດຕະວະແພດ','Veterinary Border Checkpoint',TRUE),
('VET_DRUG_EQUIPMENT_SHOP','ຮ້ານຂາຍຢາສັດ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Drug & Equipment Shop',TRUE),
('VET_TREATMENT_ROOM','ຫ້ອງປິ່ນປົວສັດ','Veterinary Treatment Room',TRUE),
('VET_CLINIC','ຄລີນິກສັດ','Veterinary Clinic',TRUE),
('VET_HOSPITAL','ໂຮງໝໍສັດ','Veterinary Hospital',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

INSERT INTO licensing.license_type(code,name_lo,name_en,is_active) VALUES
('VET_DRUG_EQUIPMENT_SHOP','ໃບອະນຸຍາດຮ້ານຂາຍຢາສັດ ແລະ ອຸປະກອນ','Veterinary Drug & Equipment Shop License',TRUE),
('VET_TREATMENT_ROOM','ໃບອະນຸຍາດຫ້ອງປິ່ນປົວສັດ','Veterinary Treatment Room License',TRUE),
('VET_CLINIC','ໃບອະນຸຍາດຄລີນິກສັດ','Veterinary Clinic License',TRUE),
('VET_HOSPITAL','ໃບອະນຸຍາດໂຮງໝໍສັດ','Veterinary Hospital License',TRUE)
ON CONFLICT(code) DO UPDATE SET name_lo=EXCLUDED.name_lo,name_en=EXCLUDED.name_en,is_active=TRUE;

CREATE TABLE IF NOT EXISTS licensing.license_authority_rule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_type_id UUID NOT NULL REFERENCES licensing.license_type(id) ON DELETE RESTRICT,
  establishment_class_code VARCHAR(60),
  issuing_level VARCHAR(30) NOT NULL CHECK(issuing_level IN ('CENTRAL','PROVINCE','DISTRICT')),
  review_level VARCHAR(30) CHECK(review_level IS NULL OR review_level IN ('CENTRAL','PROVINCE','DISTRICT')),
  admin_unit_type_code VARCHAR(30),
  legal_reference TEXT,
  effective_from DATE,
  effective_to DATE,
  policy_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT' CHECK(policy_status IN ('DRAFT','APPROVED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_license_authority_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from)
);
CREATE INDEX IF NOT EXISTS idx_license_authority_rule_type ON licensing.license_authority_rule(license_type_id,policy_status);
DROP TRIGGER IF EXISTS trg_license_authority_rule_updated_at ON licensing.license_authority_rule;
CREATE TRIGGER trg_license_authority_rule_updated_at BEFORE UPDATE ON licensing.license_authority_rule
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
COMMENT ON TABLE licensing.license_authority_rule IS
'Controlled delegation matrix. DRAFT rows are not legal authority; only formally approved rules should drive issuance.';

CREATE OR REPLACE VIEW analytics.v_user_access_matrix AS
SELECT
  ura.id AS assignment_id,
  u.id AS user_id,
  u.username,
  u.email,
  u.status AS user_status,
  r.code AS role_code,
  r.name_lo AS role_name_lo,
  r.name_en AS role_name_en,
  s.id AS access_scope_id,
  s.scope_name,
  s.scope_type,
  s.is_global,
  s.domain_code,
  s.organization_id,
  o.organization_code,
  o.name_lo AS organization_name_lo,
  o.name_en AS organization_name_en,
  s.admin_unit_id,
  au.official_code AS admin_unit_code,
  au.name_lo AS admin_unit_name_lo,
  au.name_en AS admin_unit_name_en,
  aut.code AS admin_unit_type_code,
  s.facility_id,
  f.facility_no,
  f.name_lo AS facility_name_lo,
  f.name_en AS facility_name_en,
  ura.valid_from,
  ura.valid_to,
  ura.status AS assignment_status
FROM security.user_role_assignment ura
JOIN security.app_user u ON u.id=ura.user_id
JOIN security.role r ON r.id=ura.role_id
LEFT JOIN security.access_scope s ON s.id=ura.access_scope_id
LEFT JOIN master.organization o ON o.id=s.organization_id
LEFT JOIN master.admin_unit au ON au.id=s.admin_unit_id
LEFT JOIN lookup.admin_unit_type aut ON aut.id=au.admin_unit_type_id
LEFT JOIN master.facility f ON f.id=s.facility_id;

-- ============================================================================
-- MIGRATION: 000840_import_plan_analytics.sql
-- ============================================================================
-- LVSP v1.9.0 — Import Plan & Analytics
-- Non-destructive analytics layer over 000780 + 000790 + 000810.
-- Purpose:
--   * Track annual plan vs approved vs actual cleared imports.
--   * Never subtract incompatible quantity units.
--   * Support category/summary plans by item-count/value rather than mixing units.
--   * Power company/product/checkpoint rankings and drill-down reports.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('trade.import_plan') IS NULL THEN missing := array_append(missing,'trade.import_plan'); END IF;
  IF to_regclass('trade.import_plan_item') IS NULL THEN missing := array_append(missing,'trade.import_plan_item'); END IF;
  IF to_regclass('trade.import_plan_item_profile') IS NULL THEN missing := array_append(missing,'trade.import_plan_item_profile'); END IF;
  IF to_regclass('trade.import_application') IS NULL THEN missing := array_append(missing,'trade.import_application'); END IF;
  IF to_regclass('trade.import_application_item') IS NULL THEN missing := array_append(missing,'trade.import_application_item'); END IF;
  IF to_regclass('master.company') IS NULL THEN missing := array_append(missing,'master.company'); END IF;
  IF cardinality(missing)>0 THEN
    RAISE EXCEPTION '000840 prerequisites missing: %',array_to_string(missing,', ');
  END IF;
END $$;

-- One row per application item.  This is the stable source for analytics.
CREATE OR REPLACE VIEW analytics.v_import_transaction_detail AS
SELECT
  iai.id AS application_item_id,
  ia.id AS application_id,
  ia.application_no,
  ia.permit_no,
  ia.import_type AS movement_type,
  ia.application_date,
  ia.decision_date,
  ia.cleared_date,
  ia.status AS application_status,
  ia.company_id,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
  ia.plan_id,
  ip.plan_no,
  ip.plan_year,
  iai.plan_item_id,
  pi.item_no AS plan_item_no,
  pi.item_name AS plan_reference_name,
  pi.item_type AS plan_item_type,
  pi.line_mode,
  pi.group_code,
  pi.group_name,
  COALESCE(pip.scope_type,'ITEM') AS scope_type,
  COALESCE(pip.category_code,pi.group_code) AS category_code,
  CASE
    WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
         AND (
           COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
           OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
         )
      THEN 'COUNT_VALUE'
    ELSE COALESCE(pip.tracking_basis,'QUANTITY')
  END AS tracking_basis,
  COALESCE(
    pip.planned_item_count,
    pi.planned_item_count,
    CASE WHEN COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
              OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
         THEN CASE WHEN pi.planned_quantity BETWEEN 0 AND 2147483647 THEN floor(pi.planned_quantity)::integer END
    END
  ) AS planned_item_count,
  pi.planned_quantity,
  COALESCE(pip.planned_value_usd,pi.planned_value) AS planned_value_usd,
  pi.unit_code AS plan_unit_code,
  iai.item_no AS application_item_no,
  iai.item_type,
  iai.item_name,
  iai.product_id,
  iai.device_id,
  iai.registration_no,
  iai.package_description,
  iai.requested_quantity,
  iai.approved_quantity,
  COALESCE(iai.cleared_quantity,iai.cleared_packs,0)::numeric(18,3) AS cleared_quantity,
  iai.unit_code,
  iai.item_value,
  iai.currency_code,
  iai.eligibility_status,
  iai.antimicrobial,
  iai.active_substance_kg,
  ia.origin_country,
  ia.destination_country,
  ia.border_checkpoint,
  ia.checkpoint_out,
  ia.transport_mode,
  COALESCE(pr.manufacturer_name,'') AS manufacturer_name,
  COALESCE(pr.manufacturer_country,'') AS manufacturer_country,
  CASE
    WHEN iai.plan_item_id IS NULL THEN NULL
    WHEN NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL THEN TRUE
    WHEN NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL THEN TRUE
    ELSE lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code))
  END AS unit_compatible,
  CASE
    WHEN iai.plan_item_id IS NOT NULL
         AND (NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL
              OR NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL
              OR lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code)))
         AND (CASE
              WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
                   AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                        OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
                THEN 'COUNT_VALUE'
              ELSE COALESCE(pip.tracking_basis,'QUANTITY') END) IN ('QUANTITY','QUANTITY_VALUE')
      THEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0)::numeric(18,3)
    ELSE 0::numeric(18,3)
  END AS safe_cleared_quantity,
  CASE
    WHEN iai.plan_item_id IS NOT NULL
         AND (NULLIF(btrim(COALESCE(pi.unit_code,'')),'') IS NULL
              OR NULLIF(btrim(COALESCE(iai.unit_code,'')),'') IS NULL
              OR lower(btrim(pi.unit_code))=lower(btrim(iai.unit_code)))
         AND (CASE
              WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
                   AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                        OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
                THEN 'COUNT_VALUE'
              ELSE COALESCE(pip.tracking_basis,'QUANTITY') END) IN ('QUANTITY','QUANTITY_VALUE')
      THEN COALESCE(iai.approved_quantity,iai.requested_quantity,0)::numeric(18,3)
    ELSE 0::numeric(18,3)
  END AS safe_approved_quantity,
  CASE
    WHEN upper(COALESCE(ia.status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED')
      THEN COALESCE(iai.item_value,0)::numeric(20,2)
    ELSE 0::numeric(20,2)
  END AS approved_value_usd,
  CASE
    WHEN COALESCE(iai.cleared_quantity,iai.cleared_packs,0)>0
         AND COALESCE(iai.item_value,0)>0
         AND COALESCE(iai.approved_quantity,iai.requested_quantity,0)>0
      THEN ROUND(
        COALESCE(iai.item_value,0)
        * LEAST(1::numeric,
          COALESCE(iai.cleared_quantity,iai.cleared_packs,0)
          / NULLIF(COALESCE(iai.approved_quantity,iai.requested_quantity,0),0)
        ),2)
    WHEN upper(COALESCE(ia.status,'')) IN ('CLEARED','CLOSED','COMPLETED')
      THEN COALESCE(iai.item_value,0)::numeric(20,2)
    ELSE 0::numeric(20,2)
  END AS actual_cleared_value_usd,
  CASE
    WHEN iai.product_id IS NOT NULL THEN 'PRODUCT:'||iai.product_id::text
    WHEN iai.device_id IS NOT NULL THEN 'DEVICE:'||iai.device_id::text
    WHEN NULLIF(btrim(COALESCE(iai.registration_no,'')),'') IS NOT NULL THEN 'REG:'||lower(btrim(iai.registration_no))
    ELSE 'NAME:'||lower(regexp_replace(btrim(COALESCE(iai.item_name,'')),'\s+',' ','g'))
  END AS actual_item_key,
  ia.created_at AS application_created_at,
  ia.updated_at AS application_updated_at,
  iai.created_at AS item_created_at
FROM trade.import_application_item iai
JOIN trade.import_application ia ON ia.id=iai.application_id
LEFT JOIN master.company c ON c.party_id=ia.company_id
LEFT JOIN trade.import_plan ip ON ip.id=ia.plan_id
LEFT JOIN trade.import_plan_item pi ON pi.id=iai.plan_item_id
LEFT JOIN trade.import_plan_item_profile pip ON pip.plan_item_id=pi.id
LEFT JOIN product.product_regulatory_profile pr ON pr.product_id=iai.product_id;

COMMENT ON VIEW analytics.v_import_transaction_detail IS
'One row per trade application item for plan/import analytics. Quantities are kept by unit; safe_* quantity fields are zero when plan/application units are incompatible or the plan tracks count/value instead of quantity.';

-- One row per annual-plan line with tracking-basis-aware balances.
CREATE OR REPLACE VIEW analytics.v_import_plan_tracking AS
WITH base AS (
  SELECT
    pi.id AS plan_item_id,
    pi.plan_id,
    ip.plan_no,
    ip.plan_year,
    ip.company_id,
    COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
    pi.item_no,
    pi.item_type,
    pi.item_name,
    pi.registration_no,
    pi.line_mode,
    pi.group_code,
    pi.group_name,
    pi.unit_code,
    pi.planned_quantity,
    COALESCE(pip.planned_value_usd,pi.planned_value) AS planned_value_usd,
    COALESCE(pip.scope_type,'ITEM') AS scope_type,
    COALESCE(pip.category_code,pi.group_code) AS category_code,
    CASE
      WHEN COALESCE(pip.tracking_basis,'QUANTITY')='QUANTITY'
           AND (COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items'))
        THEN 'COUNT_VALUE'
      ELSE COALESCE(pip.tracking_basis,'QUANTITY')
    END AS tracking_basis,
    COALESCE(
      pip.planned_item_count,
      pi.planned_item_count,
      CASE WHEN COALESCE(pi.line_mode,'ITEM')='SUMMARY_GROUP'
                OR lower(btrim(COALESCE(pi.unit_code,''))) IN ('ລາຍການ','item','items')
           THEN CASE WHEN pi.planned_quantity BETWEEN 0 AND 2147483647 THEN floor(pi.planned_quantity)::integer END
      END
    ) AS planned_item_count
  FROM trade.import_plan_item pi
  JOIN trade.import_plan ip ON ip.id=pi.plan_id
  LEFT JOIN master.company c ON c.party_id=ip.company_id
  LEFT JOIN trade.import_plan_item_profile pip ON pip.plan_item_id=pi.id
  WHERE COALESCE(pi.record_status,'ACTIVE')='ACTIVE'
), actual AS (
  SELECT
    d.plan_item_id,
    COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
    COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.actual_item_key END)::integer AS approved_item_count,
    COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
    COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.actual_item_key END)::integer AS actual_item_count,
    COALESCE(SUM(d.safe_approved_quantity),0)::numeric(20,3) AS approved_quantity,
    COALESCE(SUM(d.safe_cleared_quantity),0)::numeric(20,3) AS actual_cleared_quantity,
    COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
    COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd,
    COUNT(*) FILTER (WHERE d.plan_item_id IS NOT NULL AND d.unit_compatible=FALSE)::integer AS unit_mismatch_count,
    COUNT(*)::integer AS linked_line_count
  FROM analytics.v_import_transaction_detail d
  WHERE d.plan_item_id IS NOT NULL
  GROUP BY d.plan_item_id
)
SELECT
  b.*,
  COALESCE(a.approval_count,0) AS approval_count,
  COALESCE(a.approved_item_count,0) AS approved_item_count,
  COALESCE(a.import_count,0) AS import_count,
  COALESCE(a.actual_item_count,0) AS actual_item_count,
  COALESCE(a.approved_quantity,0) AS approved_quantity,
  COALESCE(a.actual_cleared_quantity,0) AS actual_cleared_quantity,
  COALESCE(a.approved_value_usd,0) AS approved_value_usd,
  COALESCE(a.actual_cleared_value_usd,0) AS actual_cleared_value_usd,
  COALESCE(a.unit_mismatch_count,0) AS unit_mismatch_count,
  COALESCE(a.linked_line_count,0) AS linked_line_count,
  CASE WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE')
       THEN b.planned_quantity-COALESCE(a.actual_cleared_quantity,0) END AS remaining_quantity,
  CASE WHEN b.tracking_basis IN ('COUNT_VALUE')
       THEN b.planned_item_count-COALESCE(a.actual_item_count,0) END AS remaining_item_count,
  CASE WHEN b.tracking_basis IN ('VALUE','QUANTITY_VALUE','COUNT_VALUE') AND b.planned_value_usd IS NOT NULL
       THEN b.planned_value_usd-COALESCE(a.actual_cleared_value_usd,0) END AS remaining_value_usd,
  CASE
    WHEN COALESCE(a.unit_mismatch_count,0)>0 AND b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') THEN 'UNIT_MISMATCH'
    WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') AND COALESCE(a.actual_cleared_quantity,0)>b.planned_quantity THEN 'OVER_PLAN'
    WHEN b.tracking_basis='COUNT_VALUE' AND b.planned_item_count IS NOT NULL AND COALESCE(a.actual_item_count,0)>b.planned_item_count THEN 'OVER_PLAN'
    WHEN b.tracking_basis IN ('VALUE','QUANTITY_VALUE','COUNT_VALUE') AND b.planned_value_usd IS NOT NULL AND COALESCE(a.actual_cleared_value_usd,0)>b.planned_value_usd THEN 'OVER_PLAN'
    WHEN b.tracking_basis='REFERENCE_ONLY' THEN 'REFERENCE_ONLY'
    WHEN COALESCE(a.import_count,0)=0 THEN 'NOT_USED'
    WHEN b.tracking_basis IN ('QUANTITY','QUANTITY_VALUE') AND b.planned_quantity-COALESCE(a.actual_cleared_quantity,0)<=0 THEN 'EXHAUSTED'
    WHEN b.tracking_basis='COUNT_VALUE' AND b.planned_item_count IS NOT NULL AND b.planned_item_count-COALESCE(a.actual_item_count,0)<=0 THEN 'EXHAUSTED'
    WHEN b.tracking_basis='VALUE' AND b.planned_value_usd IS NOT NULL AND b.planned_value_usd-COALESCE(a.actual_cleared_value_usd,0)<=0 THEN 'EXHAUSTED'
    ELSE 'AVAILABLE'
  END AS tracking_status
FROM base b
LEFT JOIN actual a ON a.plan_item_id=b.plan_item_id;

COMMENT ON VIEW analytics.v_import_plan_tracking IS
'Annual-plan line tracking with separate quantity, value and item-count bases. Summary/category plans track distinct item counts (with optional value) and never subtract mixed physical units from item counts.';

CREATE OR REPLACE VIEW analytics.v_import_company_summary AS
SELECT
  d.company_id,
  d.company_name,
  COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer) AS report_year,
  COUNT(DISTINCT d.application_id)::integer AS application_count,
  COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
  COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
  COUNT(DISTINCT d.actual_item_key)::integer AS unique_item_count,
  COUNT(*)::integer AS line_count,
  COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
  COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd,
  COALESCE(SUM(d.active_substance_kg),0)::numeric(20,6) AS active_substance_kg
FROM analytics.v_import_transaction_detail d
GROUP BY d.company_id,d.company_name,COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer);

CREATE OR REPLACE VIEW analytics.v_import_product_summary AS
SELECT
  d.actual_item_key,
  d.item_name,
  d.registration_no,
  d.item_type,
  d.unit_code,
  COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer) AS report_year,
  COUNT(DISTINCT d.application_id)::integer AS application_count,
  COUNT(DISTINCT CASE WHEN upper(COALESCE(d.application_status,'')) IN ('APPROVED','CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS approval_count,
  COUNT(DISTINCT CASE WHEN d.actual_cleared_value_usd>0 OR d.cleared_quantity>0 OR upper(COALESCE(d.application_status,'')) IN ('CLEARED','CLOSED','COMPLETED') THEN d.application_id END)::integer AS import_count,
  COUNT(DISTINCT d.company_id)::integer AS company_count,
  COALESCE(SUM(d.requested_quantity),0)::numeric(20,3) AS requested_quantity,
  COALESCE(SUM(COALESCE(d.approved_quantity,d.requested_quantity,0)),0)::numeric(20,3) AS approved_quantity,
  COALESCE(SUM(d.cleared_quantity),0)::numeric(20,3) AS actual_cleared_quantity,
  COALESCE(SUM(d.approved_value_usd),0)::numeric(20,2) AS approved_value_usd,
  COALESCE(SUM(d.actual_cleared_value_usd),0)::numeric(20,2) AS actual_cleared_value_usd
FROM analytics.v_import_transaction_detail d
GROUP BY d.actual_item_key,d.item_name,d.registration_no,d.item_type,d.unit_code,
         COALESCE(d.plan_year,EXTRACT(YEAR FROM d.application_date)::integer);

COMMENT ON VIEW analytics.v_import_product_summary IS
'Product summary groups quantity by product and unit. Different units are deliberately never merged into one quantity total.';

-- ============================================================================
-- MIGRATION: 000850_national_ecert_verification_foundation.sql
-- ============================================================================
-- LVSP 000850 — National e-Cert & Public Verification Foundation
-- Additive only. Existing regulatory records are not changed.
CREATE SCHEMA IF NOT EXISTS certification;

CREATE TABLE IF NOT EXISTS certification.ecert_document (
  ecert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  certificate_no TEXT NOT NULL UNIQUE,
  verification_code TEXT NOT NULL UNIQUE,
  document_type_code TEXT NOT NULL,
  source_module_code TEXT NOT NULL,
  source_record_type TEXT,
  source_record_id TEXT,
  case_reference_no TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN (
    'DRAFT','UNDER_REVIEW','APPROVED','ISSUED','SENT','RECEIVED','ACCEPTED',
    'REPLACEMENT_REQUESTED','REPLACED','REJECTED','CANCELLED','EXPIRED')),
  standard_profile TEXT NOT NULL DEFAULT 'UNCEFACT_ECERT',
  standard_version TEXT,
  issue_date TIMESTAMPTZ,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  issuer_scope_type TEXT CHECK (issuer_scope_type IS NULL OR issuer_scope_type IN ('CENTRAL','PROVINCE','DISTRICT','CHECKPOINT','OTHER')),
  issuer_scope_id TEXT,
  issuer_public_name TEXT,
  issuer_office_code TEXT,
  signatory_name_snapshot TEXT,
  signatory_title_snapshot TEXT,
  origin_country_code TEXT,
  destination_country_code TEXT,
  entry_checkpoint_code TEXT,
  exit_checkpoint_code TEXT,
  subject_summary TEXT,
  public_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  structured_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  payload_xml TEXT,
  payload_hash TEXT,
  qr_target_path TEXT,
  previous_ecert_id UUID REFERENCES certification.ecert_document(ecert_id),
  replacement_reason TEXT,
  paper_fallback_allowed BOOLEAN NOT NULL DEFAULT TRUE,
  electronically_signed BOOLEAN NOT NULL DEFAULT FALSE,
  created_by_user_id TEXT,
  issued_by_user_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_document_status ON certification.ecert_document(status);
CREATE INDEX IF NOT EXISTS idx_ecert_document_module ON certification.ecert_document(source_module_code);
CREATE INDEX IF NOT EXISTS idx_ecert_document_case ON certification.ecert_document(case_reference_no);
CREATE INDEX IF NOT EXISTS idx_ecert_document_valid_until ON certification.ecert_document(valid_until);

CREATE TABLE IF NOT EXISTS certification.ecert_status_history (
  history_id BIGSERIAL PRIMARY KEY,
  ecert_id UUID NOT NULL REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  from_status TEXT,
  to_status TEXT NOT NULL,
  reason TEXT,
  actor_user_id TEXT,
  actor_scope_type TEXT,
  actor_scope_id TEXT,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_status_history_ecert ON certification.ecert_status_history(ecert_id,event_at DESC);

CREATE TABLE IF NOT EXISTS certification.ecert_acknowledgement (
  acknowledgement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ecert_id UUID NOT NULL REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  acknowledgement_code TEXT NOT NULL CHECK (acknowledgement_code IN ('RECEIVED','ACCEPTED','REPLACEMENT_REQUESTED','REJECTED')),
  channel TEXT NOT NULL DEFAULT 'WEB' CHECK (channel IN ('WEB','API','G2G','MANUAL')),
  partner_country_code TEXT,
  partner_system_name TEXT,
  partner_message_id TEXT,
  remarks TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ecert_ack_ecert ON certification.ecert_acknowledgement(ecert_id,acknowledged_at DESC);

CREATE TABLE IF NOT EXISTS certification.ecert_exchange_message (
  exchange_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ecert_id UUID REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  direction TEXT NOT NULL CHECK (direction IN ('OUTBOUND','INBOUND')),
  message_type TEXT NOT NULL CHECK (message_type IN ('CERTIFICATE','ACKNOWLEDGEMENT','REPLACEMENT','CANCELLATION','STATUS')),
  payload_format TEXT NOT NULL DEFAULT 'JSON' CHECK (payload_format IN ('JSON','XML','PDF','XLS')),
  partner_country_code TEXT,
  partner_system_name TEXT,
  external_message_id TEXT,
  delivery_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (delivery_status IN ('PENDING','SENT','DELIVERED','FAILED','ACKNOWLEDGED')),
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  payload_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ecert_exchange_status ON certification.ecert_exchange_message(delivery_status,created_at);

CREATE TABLE IF NOT EXISTS certification.ecert_verification_event (
  verification_event_id BIGSERIAL PRIMARY KEY,
  ecert_id UUID REFERENCES certification.ecert_document(ecert_id) ON DELETE SET NULL,
  query_kind TEXT NOT NULL DEFAULT 'PUBLIC_WEB' CHECK (query_kind IN ('PUBLIC_WEB','QR','API','G2G','INTERNAL')),
  query_fingerprint TEXT,
  result_code TEXT NOT NULL CHECK (result_code IN ('VALID','EXPIRED','CANCELLED','REPLACED','REJECTED','NOT_FOUND','NOT_PUBLIC')),
  requester_country_code TEXT,
  requester_system_name TEXT,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS certification.ecert_module_policy (
  module_code TEXT NOT NULL,
  document_type_code TEXT NOT NULL,
  lifecycle_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  public_verification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  g2g_exchange_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  electronic_only_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  paper_fallback_allowed BOOLEAN NOT NULL DEFAULT TRUE,
  issuing_authority_scope_rule TEXT,
  approval_role_code TEXT,
  standard_profile TEXT NOT NULL DEFAULT 'UNCEFACT_ECERT',
  configuration_status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED')),
  notes TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (module_code,document_type_code)
);
COMMENT ON TABLE certification.ecert_module_policy IS 'Controlled configuration. Legal issuing authority is deliberately not hard-coded by migration.';

CREATE OR REPLACE VIEW certification.v_public_ecert_verification AS
SELECT d.certificate_no,d.verification_code,d.document_type_code,d.source_module_code,d.case_reference_no,
  CASE WHEN d.status='CANCELLED' THEN 'CANCELLED'
       WHEN d.status='REPLACED' THEN 'REPLACED'
       WHEN d.status='REJECTED' THEN 'REJECTED'
       WHEN d.status NOT IN ('ISSUED','SENT','RECEIVED','ACCEPTED') THEN 'NOT_PUBLIC'
       WHEN d.valid_until IS NOT NULL AND d.valid_until<now() THEN 'EXPIRED'
       ELSE 'VALID' END AS verification_status,
  d.status AS lifecycle_status,d.issue_date,d.valid_from,d.valid_until,d.issuer_public_name,d.issuer_office_code,
  d.origin_country_code,d.destination_country_code,d.entry_checkpoint_code,d.exit_checkpoint_code,
  d.subject_summary,d.public_payload,d.electronically_signed,d.paper_fallback_allowed,d.previous_ecert_id
FROM certification.ecert_document d;
COMMENT ON VIEW certification.v_public_ecert_verification IS 'Public-safe e-Cert projection; confidential structured_payload and XML are excluded.';

CREATE OR REPLACE VIEW certification.v_ecert_exchange_monitor AS
SELECT d.certificate_no,d.document_type_code,d.source_module_code,d.status AS certificate_status,
 x.direction,x.message_type,x.payload_format,x.partner_country_code,x.partner_system_name,
 x.delivery_status,x.attempt_count,x.created_at,x.sent_at,x.acknowledged_at,x.last_error
FROM certification.ecert_exchange_message x LEFT JOIN certification.ecert_document d ON d.ecert_id=x.ecert_id;

CREATE OR REPLACE FUNCTION certification.verify_public_ecert(p_query TEXT)
RETURNS TABLE (
 certificate_no TEXT, verification_code TEXT, document_type_code TEXT, source_module_code TEXT,
 case_reference_no TEXT, verification_status TEXT, lifecycle_status TEXT, issue_date TIMESTAMPTZ,
 valid_from TIMESTAMPTZ, valid_until TIMESTAMPTZ, issuer_public_name TEXT, origin_country_code TEXT,
 destination_country_code TEXT, subject_summary TEXT, public_payload JSONB,
 electronically_signed BOOLEAN, paper_fallback_allowed BOOLEAN)
LANGUAGE sql STABLE AS $$
 SELECT v.certificate_no,v.verification_code,v.document_type_code,v.source_module_code,v.case_reference_no,
 v.verification_status,v.lifecycle_status,v.issue_date,v.valid_from,v.valid_until,v.issuer_public_name,
 v.origin_country_code,v.destination_country_code,v.subject_summary,v.public_payload,
 v.electronically_signed,v.paper_fallback_allowed
 FROM certification.v_public_ecert_verification v
 WHERE lower(v.certificate_no)=lower(trim(p_query)) OR lower(v.verification_code)=lower(trim(p_query))
 LIMIT 10
$$;
COMMENT ON FUNCTION certification.verify_public_ecert(TEXT) IS 'Public-safe verification lookup by certificate number or verification code.';

-- ============================================================================
-- MIGRATION: 000860_annual_trade_plan_ecert_bridge.sql
-- ============================================================================
-- LVSP 000860 — Annual Trade Plan + National e-Cert Bridge Foundation
-- Additive integration over 000780/000790/000840 annual-plan architecture
-- and 000130/000530/000531/000850 certificate architecture.
--
-- SAFETY / DESIGN
-- * Existing annual-plan and certificate tables are retained.
-- * Existing regulatory records are not deleted or rewritten.
-- * Legal issuing authority and destination-country attestations are NOT hard-coded.
-- * Pet health certification is modeled for EXPORT only.
-- * New policy/profile rows remain DRAFT until competent legal/domain review.

DO $$
DECLARE
  missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regclass('trade.import_plan') IS NULL THEN missing := array_append(missing,'trade.import_plan'); END IF;
  IF to_regclass('trade.import_plan_profile') IS NULL THEN missing := array_append(missing,'trade.import_plan_profile'); END IF;
  IF to_regclass('analytics.v_import_plan_tracking') IS NULL THEN missing := array_append(missing,'analytics.v_import_plan_tracking'); END IF;
  IF to_regclass('document.certificate') IS NULL THEN missing := array_append(missing,'document.certificate'); END IF;
  IF to_regclass('trade.health_certificate') IS NULL THEN missing := array_append(missing,'trade.health_certificate'); END IF;
  IF to_regclass('certification.ecert_document') IS NULL THEN missing := array_append(missing,'certification.ecert_document'); END IF;
  IF to_regclass('certification.ecert_module_policy') IS NULL THEN missing := array_append(missing,'certification.ecert_module_policy'); END IF;
  IF to_regclass('system.module_catalog') IS NULL THEN missing := array_append(missing,'system.module_catalog'); END IF;
  IF cardinality(missing)>0 THEN
    RAISE EXCEPTION '000860 prerequisites missing: %',array_to_string(missing,', ');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Broaden the EXISTING trade item classification without replacing tables.
-- ---------------------------------------------------------------------------

ALTER TABLE trade.import_plan_item
  DROP CONSTRAINT IF EXISTS import_plan_item_item_type_check;
ALTER TABLE trade.import_plan_item
  ADD CONSTRAINT ck_import_plan_item_type_v112 CHECK(item_type IN (
    'MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT',
    'FEED_PRODUCT','FEED_INGREDIENT','LIVE_ANIMAL','ANIMAL_PRODUCT','ANIMAL_BYPRODUCT',
    'EGG','AQUATIC_ANIMAL','AQUATIC_PRODUCT'
  )) NOT VALID;
ALTER TABLE trade.import_plan_item VALIDATE CONSTRAINT ck_import_plan_item_type_v112;

ALTER TABLE trade.import_application_item
  DROP CONSTRAINT IF EXISTS import_application_item_item_type_check;
ALTER TABLE trade.import_application_item
  ADD CONSTRAINT ck_import_application_item_type_v112 CHECK(item_type IN (
    'MEDICINE','VACCINE','BIOLOGICAL','VETERINARY_DEVICE','DIAGNOSTIC_KIT','OTHER_VETERINARY_PRODUCT',
    'FEED_PRODUCT','FEED_INGREDIENT','LIVE_ANIMAL','ANIMAL_PRODUCT','ANIMAL_BYPRODUCT',
    'EGG','AQUATIC_ANIMAL','AQUATIC_PRODUCT'
  )) NOT VALID;
ALTER TABLE trade.import_application_item VALIDATE CONSTRAINT ck_import_application_item_type_v112;

-- ---------------------------------------------------------------------------
-- 2) Annual Trade Plan service catalogue.
--    Physical table names trade.import_plan / import_plan_profile stay unchanged.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trade.annual_plan_service_type (
  service_type VARCHAR(80) PRIMARY KEY,
  module_code VARCHAR(100),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  annual_plan_required BOOLEAN NOT NULL DEFAULT TRUE,
  allowed_movements JSONB NOT NULL DEFAULT '["IMPORT"]'::jsonb,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_annual_plan_service_movements_array CHECK(jsonb_typeof(allowed_movements)='array')
);

INSERT INTO trade.annual_plan_service_type
(service_type,module_code,name_lo,name_en,annual_plan_required,allowed_movements,configuration_status,notes)
VALUES
('VET_DRUG_DEVICE','VET_DRUG_TRADE',
 'ຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ','Veterinary Drugs & Devices',
 TRUE,'["IMPORT"]'::jsonb,'DRAFT',
 'Existing operational annual-plan work area; catalogue row does not change existing plan records.'),
('ANIMAL_FEED','ANIMAL_FEED_TRADE',
 'ອາຫານສັດ ແລະ ວັດຖຸປະສົມ/ວັດຖຸດິບອາຫານສັດ','Animal Feed & Feed Ingredients',
 TRUE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'Annual plan work area requested for import/export/transit; legal/SOP configuration remains subject to review.'),
('ANIMAL_PRODUCT','ANIMAL_PRODUCT_TRADE',
 'ຜະລິດຕະພັນກ່ຽວກັບສັດ','Animal Products',
 TRUE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'Annual plan work area requested for import/export/transit; certificate conditions remain destination-specific.'),
('LIVE_ANIMAL','ANIMAL_PRODUCT_TRADE',
 'ສັດມີຊີວິດ','Live Animals',
 FALSE,'["IMPORT","EXPORT","TRANSIT"]'::jsonb,'DRAFT',
 'No annual-plan requirement is asserted by this migration.'),
('PET_MOVEMENT','PET_MOVEMENT',
 'ໝາ-ແມວ / ສັດລ້ຽງມີຊີວິດ','Pet Dog/Cat Movement',
 FALSE,'["IMPORT","EXPORT"]'::jsonb,'DRAFT',
 'Pet movement is case/permit based; export may additionally produce a veterinary health certificate.')
ON CONFLICT(service_type) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_import_plan_profile_service_movement
  ON trade.import_plan_profile(service_type,movement_type);

COMMENT ON TABLE trade.annual_plan_service_type IS
'Configuration catalogue for the existing annual-plan engine. It does not replace trade.import_plan. DRAFT rows require legal/domain review before Production policy use.';
COMMENT ON COLUMN trade.import_plan_profile.service_type IS
'Annual Trade Plan work area. Existing physical table name is retained for backward compatibility.';

CREATE OR REPLACE FUNCTION trade.ensure_default_import_plan_profile()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO trade.import_plan_profile(import_plan_id,detail_level,movement_type,service_type)
  VALUES(NEW.id,'ITEM','IMPORT','VET_DRUG_DEVICE')
  ON CONFLICT(import_plan_id) DO NOTHING;
  RETURN NEW;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname='trg_import_plan_ensure_profile'
      AND tgrelid='trade.import_plan'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER trg_import_plan_ensure_profile
    AFTER INSERT ON trade.import_plan
    FOR EACH ROW EXECUTE FUNCTION trade.ensure_default_import_plan_profile();
  END IF;
END $$;

CREATE TRIGGER trg_annual_plan_service_type_updated_at
BEFORE UPDATE ON trade.annual_plan_service_type
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_annual_plan_service_type
BEFORE DELETE ON trade.annual_plan_service_type
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

-- ---------------------------------------------------------------------------
-- 3) Bridge established document.certificate to the 000850 national e-Cert registry.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS certification.ecert_legacy_certificate_link (
  ecert_id UUID PRIMARY KEY
    REFERENCES certification.ecert_document(ecert_id) ON DELETE RESTRICT,
  legacy_certificate_id UUID NOT NULL UNIQUE
    REFERENCES document.certificate(id) ON DELETE RESTRICT,
  link_type VARCHAR(30) NOT NULL DEFAULT 'MIGRATION_BRIDGE'
    CHECK(link_type IN ('MIGRATION_BRIDGE','ISSUANCE_BRIDGE','MANUAL_LINK')),
  source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecert_legacy_link_certificate
  ON certification.ecert_legacy_certificate_link(legacy_certificate_id);

CREATE TRIGGER trg_no_delete_ecert_legacy_certificate_link
BEFORE DELETE ON certification.ecert_legacy_certificate_link
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE certification.ecert_legacy_certificate_link IS
'Non-destructive one-to-one bridge between document.certificate and the national 000850 e-Cert registry. No legacy certificate is copied, replaced or deleted.';

-- ---------------------------------------------------------------------------
-- 4) Configurable international/destination certificate profiles.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS certification.ecert_profile (
  profile_code VARCHAR(120) PRIMARY KEY,
  profile_name_lo TEXT NOT NULL,
  profile_name_en TEXT NOT NULL,
  document_type_code VARCHAR(120) NOT NULL,
  source_module_code VARCHAR(100) NOT NULL,
  movement_type VARCHAR(20) NOT NULL
    CHECK(movement_type IN ('IMPORT','EXPORT','TRANSIT','RE_EXPORT')),
  subject_scope VARCHAR(40) NOT NULL
    CHECK(subject_scope IN ('PET','LIVE_ANIMAL','ANIMAL_PRODUCT','FEED','OTHER')),
  origin_country_code VARCHAR(3),
  destination_country_code VARCHAR(3),
  standard_profile VARCHAR(80) NOT NULL DEFAULT 'UNCEFACT_ECERT',
  standard_version TEXT,
  effective_from DATE,
  effective_to DATE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  legal_reference TEXT,
  validity_rule JSONB NOT NULL DEFAULT '{}'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_ecert_profile_dates CHECK(effective_to IS NULL OR effective_from IS NULL OR effective_to>=effective_from),
  CONSTRAINT ck_ecert_profile_validity_rule CHECK(jsonb_typeof(validity_rule)='object')
);

CREATE INDEX IF NOT EXISTS idx_ecert_profile_lookup
  ON certification.ecert_profile(source_module_code,document_type_code,movement_type,destination_country_code,configuration_status);

CREATE TABLE IF NOT EXISTS certification.ecert_profile_attestation (
  attestation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_code VARCHAR(120) NOT NULL
    REFERENCES certification.ecert_profile(profile_code) ON DELETE RESTRICT,
  sequence_no INTEGER NOT NULL CHECK(sequence_no>0),
  attestation_code VARCHAR(120) NOT NULL,
  clause_text_lo TEXT,
  clause_text_en TEXT,
  rule_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_required BOOLEAN NOT NULL DEFAULT FALSE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  legal_reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(profile_code,sequence_no),
  UNIQUE(profile_code,attestation_code),
  CONSTRAINT ck_ecert_profile_attestation_rule CHECK(jsonb_typeof(rule_payload)='object')
);

CREATE INDEX IF NOT EXISTS idx_ecert_profile_attestation_profile
  ON certification.ecert_profile_attestation(profile_code,sequence_no,configuration_status);

INSERT INTO certification.ecert_profile
(profile_code,profile_name_lo,profile_name_en,document_type_code,source_module_code,movement_type,subject_scope,configuration_status,notes)
VALUES
('PET_EXPORT_HEALTH_BASE',
 'ໃບຢັ້ງຢືນສຸຂະພາບສັດລ້ຽງສຳລັບສົ່ງອອກ',
 'Pet Export Veterinary Health Certificate',
 'PET_EXPORT_HEALTH_CERTIFICATE','PET_MOVEMENT','EXPORT','PET','DRAFT',
 'Base structural profile only. Destination-country attestations, validity and competent issuing authority are not hard-coded.'),
('LIVE_ANIMAL_EXPORT_HEALTH_BASE',
 'ໃບຢັ້ງຢືນສຸຂະພາບສັດມີຊີວິດສຳລັບສົ່ງອອກ',
 'Live Animal Export Veterinary Health Certificate',
 'LIVE_ANIMAL_EXPORT_HEALTH_CERTIFICATE','ANIMAL_PRODUCT_TRADE','EXPORT','LIVE_ANIMAL','DRAFT',
 'Base structural profile only; species/destination attestations remain configurable.'),
('ANIMAL_PRODUCT_EXPORT_SANITARY_BASE',
 'ໃບຢັ້ງຢືນສຸຂະນາໄມຜະລິດຕະພັນສັດສຳລັບສົ່ງອອກ',
 'Animal Product Export Veterinary/Sanitary Certificate',
 'ANIMAL_PRODUCT_EXPORT_SANITARY_CERTIFICATE','ANIMAL_PRODUCT_TRADE','EXPORT','ANIMAL_PRODUCT','DRAFT',
 'Base structural profile only; commodity/destination attestations remain configurable.')
ON CONFLICT(profile_code) DO NOTHING;

CREATE TRIGGER trg_ecert_profile_updated_at
BEFORE UPDATE ON certification.ecert_profile
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_ecert_profile_attestation_updated_at
BEFORE UPDATE ON certification.ecert_profile_attestation
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_ecert_profile
BEFORE DELETE ON certification.ecert_profile
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TRIGGER trg_no_delete_ecert_profile_attestation
BEFORE DELETE ON certification.ecert_profile_attestation
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE certification.ecert_profile IS
'Configurable certificate profile metadata. DRAFT does not constitute approved legal wording or issuing authority.';
COMMENT ON TABLE certification.ecert_profile_attestation IS
'Destination/species/commodity attestation clauses. No clause is seeded as legally approved by 000860.';

-- ---------------------------------------------------------------------------
-- 5) Module catalogue and e-Cert policy stubs.
-- ---------------------------------------------------------------------------

INSERT INTO system.module_catalog
(module_code,module_key,name_lo,name_en,description_lo,description_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order)
VALUES
('PET_MOVEMENT','pet_movement',
 'ນຳເຂົ້າ-ສົ່ງອອກ ໝາ-ແມວ','Pet Import / Export',
 'ຄຳຮ້ອງ ໃບອະນຸຍາດ ແລະ ໃບຢັ້ງຢືນສຸຂະພາບສຳລັບການສົ່ງອອກ',
 'Pet movement applications, permits and export veterinary health certificates',
 '🐕','IN_DEVELOPMENT',TRUE,TRUE,'CATALOG_ONLY',205)
ON CONFLICT(module_code) DO NOTHING;

INSERT INTO certification.ecert_module_policy
(module_code,document_type_code,lifecycle_enabled,public_verification_enabled,g2g_exchange_enabled,electronic_only_enabled,paper_fallback_allowed,standard_profile,configuration_status,notes)
VALUES
('PET_MOVEMENT','PET_IMPORT_PERMIT',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Pet import permit foundation. This migration does not create a Lao export-style health certificate for import.'),
('PET_MOVEMENT','PET_EXPORT_PERMIT',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Pet export permit foundation.'),
('PET_MOVEMENT','PET_EXPORT_HEALTH_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Export-only pet veterinary health certificate foundation; destination requirements are profile-driven.'),
('ANIMAL_PRODUCT_TRADE','LIVE_ANIMAL_EXPORT_HEALTH_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Live-animal export certificate foundation; species/destination requirements are not hard-coded.'),
('ANIMAL_PRODUCT_TRADE','ANIMAL_PRODUCT_EXPORT_SANITARY_CERTIFICATE',FALSE,FALSE,FALSE,FALSE,TRUE,'UNCEFACT_ECERT','DRAFT',
 'Animal-product export sanitary certificate foundation; commodity/destination requirements are not hard-coded.')
ON CONFLICT(module_code,document_type_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6) Cross-work-area annual-plan overview without replacing 000840 analytics.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.v_annual_trade_plan_overview AS
SELECT
  p.id AS plan_id,
  p.plan_no,
  p.plan_year,
  p.company_id,
  COALESCE(c.legal_name_lo,c.legal_name_en) AS company_name,
  COALESCE(pp.service_type,'VET_DRUG_DEVICE') AS service_type,
  st.module_code,
  COALESCE(st.name_lo,pp.service_type,'VET_DRUG_DEVICE') AS service_name_lo,
  COALESCE(st.name_en,pp.service_type,'Veterinary Drugs & Devices') AS service_name_en,
  COALESCE(pp.movement_type,'IMPORT') AS movement_type,
  COALESCE(pp.detail_level,'ITEM') AS detail_level,
  COALESCE(st.annual_plan_required,TRUE) AS annual_plan_required,
  p.application_date,
  p.approval_no,
  p.approval_date,
  p.status,
  COUNT(t.plan_item_id)::INTEGER AS item_count,
  COUNT(*) FILTER (WHERE t.tracking_status='OVER_PLAN')::INTEGER AS over_plan_item_count,
  COUNT(*) FILTER (WHERE t.tracking_status='EXHAUSTED')::INTEGER AS exhausted_item_count,
  COALESCE(SUM(t.approved_value_usd),0)::NUMERIC(20,2) AS approved_value_usd,
  COALESCE(SUM(t.actual_cleared_value_usd),0)::NUMERIC(20,2) AS actual_cleared_value_usd
FROM trade.import_plan p
LEFT JOIN master.company c ON c.party_id=p.company_id
LEFT JOIN trade.import_plan_profile pp ON pp.import_plan_id=p.id
LEFT JOIN trade.annual_plan_service_type st
  ON st.service_type=COALESCE(pp.service_type,'VET_DRUG_DEVICE')
LEFT JOIN analytics.v_import_plan_tracking t ON t.plan_id=p.id
GROUP BY
  p.id,p.plan_no,p.plan_year,p.company_id,c.legal_name_lo,c.legal_name_en,
  pp.service_type,pp.movement_type,pp.detail_level,
  st.module_code,st.name_lo,st.name_en,st.annual_plan_required,
  p.application_date,p.approval_no,p.approval_date,p.status;

COMMENT ON VIEW analytics.v_annual_trade_plan_overview IS
'Cross-work-area Annual Trade Plan overview layered on the existing 000780/000790/000840 plan engine. Existing import analytics remain intact.';

-- ===========================================================================
-- 7) DLF/DVS governance foundation — responsibilities can change over time.
--    Baseline rows below are PROVISIONAL, based on the DVS 2025 mandate
--    supplied for LVSP design. They are NOT a permanent legal assignment and
--    are deliberately effective-dated/configurable for future 2026+ changes.
-- ===========================================================================

CREATE SCHEMA IF NOT EXISTS governance;
CREATE SCHEMA IF NOT EXISTS integration;

CREATE TABLE IF NOT EXISTS governance.organizational_unit (
  unit_code VARCHAR(100) PRIMARY KEY,
  parent_unit_code VARCHAR(100)
    REFERENCES governance.organizational_unit(unit_code) ON DELETE RESTRICT,
  unit_type VARCHAR(30) NOT NULL
    CHECK(unit_type IN ('DEPARTMENT','DIVISION','CENTER','OFFICE','OTHER')),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from DATE,
  valid_to DATE,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_governance_unit_dates
    CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from)
);

INSERT INTO governance.organizational_unit
(unit_code,parent_unit_code,unit_type,name_lo,name_en,configuration_status,notes)
VALUES
('DLF',NULL,'DEPARTMENT',
 'ກົມລ້ຽງສັດ ແລະ ການປະມົງ',
 'Department of Livestock and Fisheries','DRAFT',
 'DLF organizational root for configurable LVSP responsibility mapping.'),
('DVS','DLF','DIVISION',
 'ພະແນກສັດຕະວະແພດ',
 'Division of Veterinary Services','DRAFT',
 'Current LVSP domain unit.'),
('LIVESTOCK_DIVISION','DLF','DIVISION',
 'ພະແນກລ້ຽງສັດ',
 'Livestock Division','DRAFT',
 'Name/code is a configurable integration placeholder; confirm against the current DLF organization list.'),
('ANIMAL_DISEASE_DIAGNOSTIC_CENTER','DLF','CENTER',
 'ສູນວິໄຈພະຍາດສັດ',
 'Animal Disease Diagnostic Center','DRAFT',
 'External service owner placeholder for laboratory/sample testing; confirm official 2026 name and mandate.')
ON CONFLICT(unit_code) DO NOTHING;

CREATE TRIGGER trg_governance_organizational_unit_updated_at
BEFORE UPDATE ON governance.organizational_unit
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_governance_organizational_unit
BEFORE DELETE ON governance.organizational_unit
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS governance.service_catalog (
  service_code VARCHAR(120) PRIMARY KEY,
  domain_code VARCHAR(80) NOT NULL,
  module_code VARCHAR(100),
  name_lo TEXT NOT NULL,
  name_en TEXT NOT NULL,
  service_kind VARCHAR(40) NOT NULL
    CHECK(service_kind IN ('REGISTRATION','PERMIT','CERTIFICATE','TRADE','INSPECTION','SURVEILLANCE','LAB_SERVICE','OTHER')),
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO governance.service_catalog
(service_code,domain_code,module_code,name_lo,name_en,service_kind,configuration_status,notes)
VALUES
('VET_DRUG_REGISTRATION','VETERINARY_PRODUCTS','VM-1003',
 'ຂຶ້ນທະບຽນຢາ ແລະ ຜະລິດຕະພັນສັດຕະວະແພດ',
 'Veterinary Drug/Product Registration','REGISTRATION','DRAFT',
 'DVS core business service.'),
('VET_DRUG_TRADE','VETERINARY_PRODUCTS','VET_DRUG_TRADE',
 'ນຳເຂົ້າຢາ ແລະ ອຸປະກອນສັດຕະວະແພດ',
 'Veterinary Drug/Device Trade','TRADE','DRAFT',
 'DVS core trade service.'),
('PET_MOVEMENT','ANIMAL_MOVEMENT','PET_MOVEMENT',
 'ນຳເຂົ້າ-ສົ່ງອອກ ໝາ-ແມວ',
 'Pet Dog/Cat Movement','PERMIT','DRAFT',
 'DVS pet movement service; export may include veterinary health certification.'),
('ANIMAL_PRODUCT_TRADE','ANIMAL_PRODUCTS','ANIMAL_PRODUCT_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ຜະລິດຕະພັນສັດ',
 'Animal Product Trade','TRADE','DRAFT',
 'DVS has veterinary/sanitary/risk responsibilities; whole administrative ownership must remain configurable.'),
('LIVE_ANIMAL_TRADE','ANIMAL_MOVEMENT','LIVE_ANIMAL_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ສັດມີຊີວິດ',
 'Live Animal Trade','TRADE','DRAFT',
 '2025 mandate indicates joint consideration with Livestock Division.'),
('ANIMAL_FEED_TRADE','FEED','ANIMAL_FEED_TRADE',
 'ນຳເຂົ້າ-ສົ່ງອອກ-ສົ່ງຜ່ານ ອາຫານສັດ ແລະ ວັດຖຸປະສົມ',
 'Animal Feed and Feed Ingredient Trade','TRADE','DRAFT',
 'DVS ownership is UNCONFIRMED pending the updated mandate.'),
('LAB_TESTING','ANIMAL_HEALTH','LAB',
 'ການເກັບ/ສົ່ງຕົວຢ່າງ ແລະ ການວິໄຈ',
 'Sample Referral and Laboratory Testing','LAB_SERVICE','DRAFT',
 'Laboratory service is treated as an external DLF-center service, not an LVSP laboratory system.'),
('EPIDEMIOLOGY_SURVEILLANCE','ANIMAL_HEALTH','AH-1001',
 'ລະບາດວິທະຍາ ແລະ ເຝົ້າລະວັງພະຍາດສັດ',
 'Veterinary Epidemiology and Surveillance','SURVEILLANCE','DRAFT',
 'DVS core animal-health responsibility.'),
('VETERINARY_BORDER_INSPECTION','BORDER','BORDER_INSPECTION',
 'ດ່ານ ແລະ ການກວດກາສັດຕະວະແພດ',
 'Veterinary Border/Checkpoint Inspection','INSPECTION','DRAFT',
 'DVS veterinary checkpoint/inspection responsibility.'),
('MEAT_HYGIENE','ANIMAL_PRODUCTS','MEAT_HYGIENE',
 'ກວດກາອະນາໄມຊີ້ນ ແລະ ສະຖານປະກອບການ',
 'Meat Hygiene and Establishment Control','INSPECTION','DRAFT',
 'DVS 2025 mandate includes meat hygiene, slaughterhouse/cold-storage related functions.')
ON CONFLICT(service_code) DO NOTHING;

CREATE TRIGGER trg_governance_service_catalog_updated_at
BEFORE UPDATE ON governance.service_catalog
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_governance_service_catalog
BEFORE DELETE ON governance.service_catalog
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS governance.service_scope_history (
  scope_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_code VARCHAR(120) NOT NULL
    REFERENCES governance.service_catalog(service_code) ON DELETE RESTRICT,
  dvs_responsibility_class VARCHAR(30) NOT NULL
    CHECK(dvs_responsibility_class IN ('DVS_LEAD','DVS_PARTICIPANT','EXTERNAL_OWNER','UNCONFIRMED')),
  lead_unit_code VARCHAR(100)
    REFERENCES governance.organizational_unit(unit_code) ON DELETE RESTRICT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  basis_version VARCHAR(80) NOT NULL,
  legal_reference TEXT,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_service_scope_dates
    CHECK(effective_to IS NULL OR effective_to>=effective_from)
);

CREATE INDEX IF NOT EXISTS idx_service_scope_history_lookup
  ON governance.service_scope_history(service_code,effective_from,effective_to,configuration_status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_service_scope_history_version
  ON governance.service_scope_history(service_code,basis_version,effective_from);

INSERT INTO governance.service_scope_history
(service_code,dvs_responsibility_class,lead_unit_code,effective_from,basis_version,configuration_status,notes)
VALUES
('VET_DRUG_REGISTRATION','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional baseline pending 2026 mandate confirmation.'),
('VET_DRUG_TRADE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional baseline pending 2026 mandate confirmation.'),
('PET_MOVEMENT','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Pet movement/certification remains configurable if responsibilities change.'),
('ANIMAL_PRODUCT_TRADE','DVS_PARTICIPANT','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'DVS veterinary/sanitary/risk role is recognized; whole administrative ownership is not hard-coded.'),
('LIVE_ANIMAL_TRADE','DVS_PARTICIPANT','LIVESTOCK_DIVISION',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 '2025 mandate indicates joint consideration with Livestock Division.'),
('ANIMAL_FEED_TRADE','UNCONFIRMED',NULL,DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Feed trade ownership is intentionally unconfirmed until updated DLF/DVS mandate is obtained.'),
('LAB_TESTING','EXTERNAL_OWNER','ANIMAL_DISEASE_DIAGNOSTIC_CENTER',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'LVSP may refer a sample/request and receive a result/reference; it does not become the laboratory system.'),
('EPIDEMIOLOGY_SURVEILLANCE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.'),
('VETERINARY_BORDER_INSPECTION','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.'),
('MEAT_HYGIENE','DVS_LEAD','DVS',DATE '2025-01-01','DVS_MANDATE_2025_PROVISIONAL','DRAFT',
 'Provisional 2025 DVS core responsibility.')
ON CONFLICT DO NOTHING;

CREATE TRIGGER trg_no_delete_governance_service_scope_history
BEFORE DELETE ON governance.service_scope_history
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE OR REPLACE VIEW governance.v_current_service_scope AS
SELECT DISTINCT ON (h.service_code)
  h.scope_id,
  h.service_code,
  s.domain_code,
  s.module_code,
  s.name_lo,
  s.name_en,
  h.dvs_responsibility_class,
  h.lead_unit_code,
  u.name_lo AS lead_unit_name_lo,
  u.name_en AS lead_unit_name_en,
  h.effective_from,
  h.effective_to,
  h.basis_version,
  h.legal_reference,
  h.configuration_status,
  h.notes
FROM governance.service_scope_history h
JOIN governance.service_catalog s ON s.service_code=h.service_code
LEFT JOIN governance.organizational_unit u ON u.unit_code=h.lead_unit_code
WHERE h.effective_from<=CURRENT_DATE
  AND (h.effective_to IS NULL OR h.effective_to>=CURRENT_DATE)
ORDER BY h.service_code,h.effective_from DESC,h.created_at DESC;

COMMENT ON VIEW governance.v_current_service_scope IS
'Effective-dated DVS responsibility view. Organizational restructuring is represented by new history rows, never by rewriting historical cases.';

-- ===========================================================================
-- 8) Single Window / inter-agency integration foundation.
--    No Customs, LNSW, DLF, Fisheries, Livestock or Lab URL/auth is hard-coded.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS integration.external_system (
  system_code VARCHAR(80) PRIMARY KEY,
  system_name TEXT NOT NULL,
  agency_name TEXT NOT NULL,
  system_type VARCHAR(30) NOT NULL
    CHECK(system_type IN ('DLF_INTERNAL','MINISTRY','CUSTOMS','SINGLE_WINDOW','LAB','OTHER_GOV','FOREIGN_GOV','OTHER')),
  environment VARCHAR(20) NOT NULL DEFAULT 'PLANNED'
    CHECK(environment IN ('PLANNED','DEV','STAGING','PRODUCTION')),
  protocol VARCHAR(30) NOT NULL DEFAULT 'REST'
    CHECK(protocol IN ('REST','SOAP','SFTP','MESSAGE_QUEUE','MANUAL','OTHER')),
  authentication_method VARCHAR(40) NOT NULL DEFAULT 'UNCONFIGURED',
  base_url TEXT,
  configuration_status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(configuration_status IN ('DRAFT','REVIEWED','APPROVED','SUSPENDED','RETIRED')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO integration.external_system
(system_code,system_name,agency_name,system_type,environment,protocol,authentication_method,configuration_status,notes)
VALUES
('DLF_GATEWAY','DLF Integration Gateway','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future DLF service/API gateway; URL and authentication intentionally blank.'),
('LIVESTOCK_SYSTEM','Livestock Division System','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future division system integration placeholder.'),
('FISHERIES_SYSTEM','Fisheries System','Department of Livestock and Fisheries','DLF_INTERNAL','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future fisheries system integration placeholder.'),
('DIAGNOSTIC_LAB','Animal Disease Diagnostic Center System','Department of Livestock and Fisheries','LAB','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Future lab referral/result integration placeholder.'),
('CUSTOMS','Lao Customs System','Lao Customs','CUSTOMS','PLANNED','REST','UNCONFIGURED','DRAFT',
 'Customs integration placeholder only; no endpoint or credential is hard-coded.'),
('LNSW','Lao National Single Window','Lao PDR','SINGLE_WINDOW','PLANNED','REST','UNCONFIGURED','DRAFT',
 'National Single Window integration placeholder only; no endpoint or credential is hard-coded.')
ON CONFLICT(system_code) DO NOTHING;

CREATE TRIGGER trg_integration_external_system_updated_at
BEFORE UPDATE ON integration.external_system
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_integration_external_system
BEFORE DELETE ON integration.external_system
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS integration.external_identifier (
  external_identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(80) NOT NULL,
  internal_reference TEXT NOT NULL,
  external_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  external_id TEXT NOT NULL,
  namespace TEXT,
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK(status IN ('ACTIVE','INACTIVE','REPLACED','REVOKED')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_external_identifier_metadata CHECK(jsonb_typeof(metadata)='object'),
  CONSTRAINT ck_external_identifier_dates CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>=valid_from),
  UNIQUE(external_system_code,entity_type,external_id)
);

CREATE INDEX IF NOT EXISTS idx_external_identifier_internal
  ON integration.external_identifier(entity_type,internal_reference,status);

CREATE TRIGGER trg_no_delete_integration_external_identifier
BEFORE DELETE ON integration.external_identifier
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

CREATE TABLE IF NOT EXISTS integration.message_envelope (
  message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_type VARCHAR(100) NOT NULL,
  schema_version VARCHAR(30) NOT NULL DEFAULT '1.0',
  source_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  destination_system_code VARCHAR(80) NOT NULL
    REFERENCES integration.external_system(system_code) ON DELETE RESTRICT,
  correlation_id UUID NOT NULL DEFAULT gen_random_uuid(),
  reference_type VARCHAR(80),
  reference_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
    CHECK(status IN ('DRAFT','QUEUED','SENT','ACKNOWLEDGED','REJECTED','FAILED','CANCELLED')),
  sent_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  error_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_integration_message_payload CHECK(jsonb_typeof(payload)='object')
);

CREATE INDEX IF NOT EXISTS idx_integration_message_correlation
  ON integration.message_envelope(correlation_id);
CREATE INDEX IF NOT EXISTS idx_integration_message_reference
  ON integration.message_envelope(reference_type,reference_id);
CREATE INDEX IF NOT EXISTS idx_integration_message_status
  ON integration.message_envelope(status,created_at);

CREATE TRIGGER trg_integration_message_envelope_updated_at
BEFORE UPDATE ON integration.message_envelope
FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

CREATE TRIGGER trg_no_delete_integration_message_envelope
BEFORE DELETE ON integration.message_envelope
FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

COMMENT ON TABLE integration.message_envelope IS
'Generic future DLF/Customs/LNSW/non-certificate message envelope. certification.ecert_exchange_message remains the authoritative e-Cert exchange model from 000850.';

CREATE OR REPLACE VIEW integration.v_single_window_readiness AS
SELECT
  e.system_code,
  e.system_name,
  e.agency_name,
  e.system_type,
  e.environment,
  e.protocol,
  e.authentication_method,
  (e.base_url IS NOT NULL AND length(trim(e.base_url))>0) AS endpoint_configured,
  e.configuration_status,
  e.notes
FROM integration.external_system e
ORDER BY e.system_type,e.system_code;

COMMENT ON VIEW integration.v_single_window_readiness IS
'Readiness/configuration view only. DRAFT/PLANNED rows do not imply a live external connection.';

-- Keep Annual Trade Plan catalog broad but prevent the migration from claiming
-- DVS ownership for feed/live-animal work.
UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for future/shared integration. DVS ownership is UNCONFIRMED pending updated mandate.',
    configuration_status='DRAFT'
WHERE service_type='ANIMAL_FEED';

UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for shared workflow. 2025 baseline treats DVS as a PARTICIPANT, not sole owner.',
    configuration_status='DRAFT'
WHERE service_type='LIVE_ANIMAL';

UPDATE trade.annual_plan_service_type
SET notes='Catalogue retained for veterinary/sanitary participation. Whole administrative ownership remains configurable.',
    configuration_status='DRAFT'
WHERE service_type='ANIMAL_PRODUCT';

-- ============================================================================
-- MIGRATION: 000870_batch_ops_botanical_hs_codes.sql
-- ============================================================================
-- =====================================================================
-- 000870_batch_ops_botanical_hs_codes.sql
-- LVSP Migration 000870 — Batch Operations + Botanical + HS/AHTN codes
-- APPEND-ONLY. NO BEGIN/COMMIT (runner wraps each file in its own txn).
-- Idempotent: IF NOT EXISTS / INSERT..WHERE NOT EXISTS / DROP..;CREATE.
-- =====================================================================

-- 1. registration.registration_type += 4 pathways ---------------------
INSERT INTO registration.registration_type(code,name_lo,name_en)
SELECT v.code, v.name_lo, v.name_en
FROM (VALUES
  ('IMPORT_FINISHED','ນຳເຂົ້າ (ຜະລິດຕະພັນສຳເລັດຮູບ)','Import (Finished Product)'),
  ('DOMESTIC_MANUFACTURE','ຜະລິດພາຍໃນປະເທດ','Domestic Manufacture'),
  ('IMPORT_BULK_REPACK','ນຳເຂົ້າ Bulk ເພື່ອບັນຈຸຄືນ','Import Bulk for Repack'),
  ('EXPORT','ສົ່ງອອກ','Export')
) AS v(code,name_lo,name_en)
WHERE NOT EXISTS (
  SELECT 1 FROM registration.registration_type rt WHERE rt.code = v.code
);

-- 2. product.product_type += TRADITIONAL_HERBAL -----------------------
INSERT INTO product.product_type(code,name_lo,name_en)
SELECT 'TRADITIONAL_HERBAL','ຜະລິດຕະພັນສະໝຸນໄພພື້ນເມືອງ','Traditional Herbal Product'
WHERE NOT EXISTS (
  SELECT 1 FROM product.product_type WHERE code='TRADITIONAL_HERBAL'
);

-- 3. reference_term BATCH_OPERATION_TYPE += REPACK/DECANT/RELABEL ------
INSERT INTO lookup.veterinary_drug_reference_term
  (domain_code,code,value_text,name_lo,name_en,sort_order)
SELECT v.domain_code,v.code,v.value_text,v.name_lo,v.name_en,v.sort_order
FROM (VALUES
  ('BATCH_OPERATION_TYPE','REPACK','Repack','ບັນຈຸຄືນ','Repack',10),
  ('BATCH_OPERATION_TYPE','DECANT','Decant','ຮ່າຍ (ແບ່ງບັນຈຸ)','Decant',20),
  ('BATCH_OPERATION_TYPE','RELABEL','Relabel','ຕິດສະຫຼາກຄືນ','Relabel',30)
) AS v(domain_code,code,value_text,name_lo,name_en,sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM lookup.veterinary_drug_reference_term t
  WHERE t.domain_code=v.domain_code AND t.code=v.code
);

-- 4. product.botanical_ingredient (multi-row per product) --------------
CREATE TABLE IF NOT EXISTS product.botanical_ingredient(
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id             uuid NOT NULL REFERENCES product.product(id),
  product_version_id     uuid REFERENCES product.product_version(id),
  sequence_no            int  NOT NULL DEFAULT 1,
  scientific_name        text NOT NULL,
  plant_family           text,
  common_name_lo         text,
  common_name_en         text,
  plant_part_ref_id      uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  preparation_ref_id     uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  extract_ratio          text,
  marker_substance       text,
  marker_qty             numeric,
  marker_unit            varchar(32),
  standardization_pct    numeric,
  source_ref_id          uuid REFERENCES lookup.veterinary_drug_reference_term(id),
  origin_country         varchar(3),
  origin_locality        text,
  reference_monograph    text,
  quality_test_reference text,
  is_active              bool NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_botanical_product_seq UNIQUE(product_id, sequence_no)
);

-- 5. product.batch_operation (REPACK/DECANT/RELABEL event) -------------
CREATE TABLE IF NOT EXISTS product.batch_operation(
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type_ref_id   uuid NOT NULL REFERENCES lookup.veterinary_drug_reference_term(id),
  facility_id             uuid REFERENCES master.facility(id),
  source_registration_id  uuid REFERENCES registration.registration(id),
  source_import_item_id   uuid REFERENCES trade.import_application_item(id),
  secondary_gmp_reference text,
  bonded_flag             bool NOT NULL DEFAULT false,
  operation_date          date,
  notes                   text,
  is_active               bool NOT NULL DEFAULT true,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- 6. product.batch_operation_link (genealogy INPUT/OUTPUT) ------------
CREATE TABLE IF NOT EXISTS product.batch_operation_link(
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id  uuid NOT NULL REFERENCES product.batch_operation(id),
  batch_id      uuid NOT NULL REFERENCES product.batch(id),
  link_role     varchar(8) NOT NULL CHECK (link_role IN ('INPUT','OUTPUT')),
  quantity      numeric,
  unit_code     varchar(32),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_batch_op_link UNIQUE(operation_id, batch_id, link_role)
);

-- 7. ADD COLUMNS: INN / HS / AHTN / GTIN / GLN ------------------------
ALTER TABLE product.ingredient                 ADD COLUMN IF NOT EXISTS inn_code  varchar(255);
ALTER TABLE product.product_regulatory_profile ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE product.product_regulatory_profile ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE trade.import_application_item       ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE trade.import_application_item       ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE trade.import_plan_item              ADD COLUMN IF NOT EXISTS hs_code   varchar(16);
ALTER TABLE trade.import_plan_item              ADD COLUMN IF NOT EXISTS ahtn_code varchar(16);
ALTER TABLE product.product                     ADD COLUMN IF NOT EXISTS gtin      varchar(14);
ALTER TABLE master.party                        ADD COLUMN IF NOT EXISTS gln       varchar(13);

-- 8. triggers on new tables ------------------------------------------
DROP TRIGGER IF EXISTS trg_botanical_ingredient_updated  ON product.botanical_ingredient;
CREATE TRIGGER trg_botanical_ingredient_updated
  BEFORE UPDATE ON product.botanical_ingredient
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
DROP TRIGGER IF EXISTS trg_botanical_ingredient_nodelete ON product.botanical_ingredient;
CREATE TRIGGER trg_botanical_ingredient_nodelete
  BEFORE DELETE ON product.botanical_ingredient
  FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_batch_operation_updated  ON product.batch_operation;
CREATE TRIGGER trg_batch_operation_updated
  BEFORE UPDATE ON product.batch_operation
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
DROP TRIGGER IF EXISTS trg_batch_operation_nodelete ON product.batch_operation;
CREATE TRIGGER trg_batch_operation_nodelete
  BEFORE DELETE ON product.batch_operation
  FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();

DROP TRIGGER IF EXISTS trg_batch_operation_link_updated ON product.batch_operation_link;
CREATE TRIGGER trg_batch_operation_link_updated
  BEFORE UPDATE ON product.batch_operation_link
  FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();

-- ============================================================================
-- MIGRATION: 000880_export_pathway_foundation.sql
-- ============================================================================
-- ============================================================================
-- LVSP Migration 000880 — Export Pathway Foundation
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມໂຄງສ້າງຂໍ້ມູນຂັ້ນຕ່ຳສຸດເພື່ອຮອງຮັບ "ການລົງທະບຽນເສັ້ນທາງສົ່ງອອກ"
-- (Export Pathway Registration) — ຂັ້ນຕອນທີ 1 ຂອງ 3
-- (Export Pathway -> e-Cert Integration -> LNSW/Single Window Integration).
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-11):
--   * ບໍ່ສ້າງ trade.export_application ເປັນ header table ໃໝ່.
--     ໃຊ້ casework.application (ຜ່ານ casework.regulatory_case) ເປັນ header ແທນ.
--   * ໃຊ້ຄືນ: trade.permit, trade.shipment, trade.health_certificate,
--     document.certificate, certification.*, governance.*,
--     trade.annual_plan_service_type (ລະບົບ annual-plan ທີ່ມີຢູ່ແລ້ວ),
--     casework.service_draft (wizard autosave, ບໍ່ສ້າງ draft table ໃໝ່).
--   * ພຽງ 2 ຕາຕະລາງເພີ່ມເຕີມ (additive-only — ບໍ່ມີ ALTER/DROP ຂອງເກົ່າ):
--       trade.export_application_detail  (1:1 ກັບ casework.application)
--       trade.export_application_item    (1:N ກັບ casework.application)
--   * HS/AHTN code = free text (ບໍ່ພົບ lookup ຕາຕະລາງສະເພາະໃນ schema ປັດຈຸບັນ).
--   * species_id / unit_id ອ້າງອີງ lookup.species(id) / lookup.unit_of_measure(id)
--     (id = uuid PK ຈິງ, ຢືນຢັນຈາກ LVSP_000880_LOOKUP_VERIFY.sh, 2026-09-11).
--
-- ອ້າງອີງ: claude/LVSP_000880_FINAL_IMPLEMENTATION_SPEC.md (ອະນຸມັດແລ້ວ)
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction control
-- ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. trade.export_application_detail
--    1:1 extension ຂອງ casework.application ສະເພາະຂໍ້ມູນສົ່ງອອກ
-- ----------------------------------------------------------------------------
CREATE TABLE trade.export_application_detail (
    id                        uuid        NOT NULL DEFAULT gen_random_uuid(),
    application_id            uuid        NOT NULL,
    service_type              varchar     NOT NULL,
    destination_country_id    uuid        NULL,
    intended_shipment_from    date        NULL,
    intended_shipment_to      date        NULL,
    notes                     text        NULL,
    created_at                timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT export_application_detail_pkey
        PRIMARY KEY (id),

    CONSTRAINT export_application_detail_application_id_key
        UNIQUE (application_id),

    CONSTRAINT export_application_detail_application_id_fkey
        FOREIGN KEY (application_id)
        REFERENCES casework.application (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_service_type_fkey
        FOREIGN KEY (service_type)
        REFERENCES trade.annual_plan_service_type (service_type)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_destination_country_id_fkey
        FOREIGN KEY (destination_country_id)
        REFERENCES lookup.country (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_detail_shipment_dates_chk
        CHECK (
            intended_shipment_from IS NULL
            OR intended_shipment_to IS NULL
            OR intended_shipment_from <= intended_shipment_to
        )
);

COMMENT ON TABLE trade.export_application_detail IS
    'LVSP 000880: export-specific 1:1 extension of casework.application (export pathway registration, step 1 of 3). Header record stays casework.application/regulatory_case.';

-- ----------------------------------------------------------------------------
-- 2. trade.export_application_item
--    1:N line items (ສິນຄ້າ) ຂອງ application ສົ່ງອອກໜຶ່ງໃບ
-- ----------------------------------------------------------------------------
CREATE TABLE trade.export_application_item (
    id                 uuid        NOT NULL DEFAULT gen_random_uuid(),
    application_id     uuid        NOT NULL,
    item_no            int         NOT NULL,
    commodity_class    varchar     NULL,
    species_id         uuid        NULL,
    product_id         uuid        NULL,
    item_description   text        NULL,
    hs_ahtn_code       varchar     NULL,
    quantity           numeric     NULL,
    unit_id            uuid        NULL,
    notes              text        NULL,

    CONSTRAINT export_application_item_pkey
        PRIMARY KEY (id),

    CONSTRAINT export_application_item_app_item_no_key
        UNIQUE (application_id, item_no),

    CONSTRAINT export_application_item_application_id_fkey
        FOREIGN KEY (application_id)
        REFERENCES casework.application (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_species_id_fkey
        FOREIGN KEY (species_id)
        REFERENCES lookup.species (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_product_id_fkey
        FOREIGN KEY (product_id)
        REFERENCES product.product (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_unit_id_fkey
        FOREIGN KEY (unit_id)
        REFERENCES lookup.unit_of_measure (id)
        ON DELETE RESTRICT,

    CONSTRAINT export_application_item_item_no_positive_chk
        CHECK (item_no > 0),

    CONSTRAINT export_application_item_quantity_nonneg_chk
        CHECK (quantity IS NULL OR quantity >= 0),

    CONSTRAINT export_application_item_commodity_class_chk
        CHECK (
            commodity_class IS NULL
            OR commodity_class IN (
                'LIVE_ANIMAL',
                'ANIMAL_PRODUCT',
                'EGG',
                'ANIMAL_BYPRODUCT',
                'AQUATIC_ANIMAL',
                'OTHER'
            )
        )
);

COMMENT ON TABLE trade.export_application_item IS
    'LVSP 000880: line items (commodity/species/product/quantity) of one export application. 1:N to casework.application via application_id. Not the same as trade.shipment_item (actual shipment goods, created later in the flow).';

-- ----------------------------------------------------------------------------
-- 3. Indexes (additive — ບໍ່ແຕະ index ເກົ່າ)
-- ----------------------------------------------------------------------------
-- NOTE: export_application_detail_application_id_key (UNIQUE) already creates
-- an implicit btree index on application_id; no extra index needed there.
-- NOTE: export_application_item_app_item_no_key (UNIQUE composite) already
-- creates an implicit btree index starting with application_id, but a plain
-- single-column index is added below too for lookups that don't filter by
-- item_no.

CREATE INDEX idx_export_application_item_application_id
    ON trade.export_application_item (application_id);

CREATE INDEX idx_export_application_item_species_id
    ON trade.export_application_item (species_id)
    WHERE species_id IS NOT NULL;

CREATE INDEX idx_export_application_item_product_id
    ON trade.export_application_item (product_id)
    WHERE product_id IS NOT NULL;

CREATE INDEX idx_export_application_item_unit_id
    ON trade.export_application_item (unit_id)
    WHERE unit_id IS NOT NULL;

CREATE INDEX idx_export_application_detail_service_type
    ON trade.export_application_detail (service_type);

CREATE INDEX idx_export_application_detail_destination_country_id
    ON trade.export_application_detail (destination_country_id)
    WHERE destination_country_id IS NOT NULL;

-- ============================================================================
-- END 000880 — 2 CREATE TABLE, 6 CREATE INDEX, 0 ALTER, 0 DROP, 0 DATA CHANGE.
-- ============================================================================

-- ============================================================================
-- MIGRATION: 000890_export_reference_data_seed.sql
-- ============================================================================
-- LVSP — 000890: Export Wizard reference data seed (Data-only, INSERT-only)
-- Purpose: populate lookup.country (full ISO 3166-1), lookup.species, and
-- lookup.unit_of_measure so the Export Application Wizard's dropdowns are not
-- empty. NO CREATE TABLE / ALTER TABLE anywhere in this file. All 3 tables
-- already exist (confirmed empty, 0 rows, via read-only audit) and this file
-- only INSERTs into them. Does not touch 000870, import tables, or any
-- casework/trade business data.
--
-- Country name_lo: per Lee's explicit instruction, countries without a
-- confidently-known Lao name use the English name in name_lo as a placeholder
-- (~60 major/ASEAN/trading-partner countries have real Lao names; the
-- remaining ~189 use English in both name_lo and name_en for now — these can
-- be corrected later with simple UPDATE statements, no schema change needed).

-- 249 countries generated
INSERT INTO lookup.country(iso2_code,iso3_code,numeric_code,name_lo,name_en,is_active) VALUES
('AD','AND','020','Andorra','Andorra',TRUE),
('AE','ARE','784','ສະຫະລັດອາຣັບເອມີເຣດ','United Arab Emirates',TRUE),
('AF','AFG','004','Afghanistan','Afghanistan',TRUE),
('AG','ATG','028','Antigua and Barbuda','Antigua and Barbuda',TRUE),
('AI','AIA','660','Anguilla','Anguilla',TRUE),
('AL','ALB','008','Albania','Albania',TRUE),
('AM','ARM','051','Armenia','Armenia',TRUE),
('AO','AGO','024','Angola','Angola',TRUE),
('AQ','ATA','010','Antarctica','Antarctica',TRUE),
('AR','ARG','032','ອາເຈນຕິນາ','Argentina',TRUE),
('AS','ASM','016','American Samoa','American Samoa',TRUE),
('AT','AUT','040','ອອສເຕຣຍ','Austria',TRUE),
('AU','AUS','036','ອົດສະຕາລີ','Australia',TRUE),
('AW','ABW','533','Aruba','Aruba',TRUE),
('AX','ALA','248','Åland Islands','Åland Islands',TRUE),
('AZ','AZE','031','Azerbaijan','Azerbaijan',TRUE),
('BA','BIH','070','Bosnia and Herzegovina','Bosnia and Herzegovina',TRUE),
('BB','BRB','052','Barbados','Barbados',TRUE),
('BD','BGD','050','ບັງກະລາເທດ','Bangladesh',TRUE),
('BE','BEL','056','ແບນຊິກ','Belgium',TRUE),
('BF','BFA','854','Burkina Faso','Burkina Faso',TRUE),
('BG','BGR','100','Bulgaria','Bulgaria',TRUE),
('BH','BHR','048','Bahrain','Bahrain',TRUE),
('BI','BDI','108','Burundi','Burundi',TRUE),
('BJ','BEN','204','Benin','Benin',TRUE),
('BL','BLM','652','Saint Barthélemy','Saint Barthélemy',TRUE),
('BM','BMU','060','Bermuda','Bermuda',TRUE),
('BN','BRN','096','ບຣູໄນ','Brunei Darussalam',TRUE),
('BO','BOL','068','Bolivia, Plurinational State of','Bolivia, Plurinational State of',TRUE),
('BQ','BES','535','Bonaire, Sint Eustatius and Saba','Bonaire, Sint Eustatius and Saba',TRUE),
('BR','BRA','076','ບຣາຊິນ','Brazil',TRUE),
('BS','BHS','044','Bahamas','Bahamas',TRUE),
('BT','BTN','064','Bhutan','Bhutan',TRUE),
('BV','BVT','074','Bouvet Island','Bouvet Island',TRUE),
('BW','BWA','072','Botswana','Botswana',TRUE),
('BY','BLR','112','Belarus','Belarus',TRUE),
('BZ','BLZ','084','Belize','Belize',TRUE),
('CA','CAN','124','ການາດາ','Canada',TRUE),
('CC','CCK','166','Cocos (Keeling) Islands','Cocos (Keeling) Islands',TRUE),
('CD','COD','180','Congo, The Democratic Republic of the','Congo, The Democratic Republic of the',TRUE),
('CF','CAF','140','Central African Republic','Central African Republic',TRUE),
('CG','COG','178','Congo','Congo',TRUE),
('CH','CHE','756','ສະວິດເຊີແລນ','Switzerland',TRUE),
('CI','CIV','384','Côte d''Ivoire','Côte d''Ivoire',TRUE),
('CK','COK','184','Cook Islands','Cook Islands',TRUE),
('CL','CHL','152','ຊິລີ','Chile',TRUE),
('CM','CMR','120','Cameroon','Cameroon',TRUE),
('CN','CHN','156','ຈີນ','China',TRUE),
('CO','COL','170','Colombia','Colombia',TRUE),
('CR','CRI','188','Costa Rica','Costa Rica',TRUE),
('CU','CUB','192','Cuba','Cuba',TRUE),
('CV','CPV','132','Cabo Verde','Cabo Verde',TRUE),
('CW','CUW','531','Curaçao','Curaçao',TRUE),
('CX','CXR','162','Christmas Island','Christmas Island',TRUE),
('CY','CYP','196','Cyprus','Cyprus',TRUE),
('CZ','CZE','203','ສາທາລະນະລັດເຊັກ','Czechia',TRUE),
('DE','DEU','276','ເຢຍລະມັນ','Germany',TRUE),
('DJ','DJI','262','Djibouti','Djibouti',TRUE),
('DK','DNK','208','ເດນມາກ','Denmark',TRUE),
('DM','DMA','212','Dominica','Dominica',TRUE),
('DO','DOM','214','Dominican Republic','Dominican Republic',TRUE),
('DZ','DZA','012','Algeria','Algeria',TRUE),
('EC','ECU','218','Ecuador','Ecuador',TRUE),
('EE','EST','233','Estonia','Estonia',TRUE),
('EG','EGY','818','ອີຢິບ','Egypt',TRUE),
('EH','ESH','732','Western Sahara','Western Sahara',TRUE),
('ER','ERI','232','Eritrea','Eritrea',TRUE),
('ES','ESP','724','ສະເປນ','Spain',TRUE),
('ET','ETH','231','Ethiopia','Ethiopia',TRUE),
('FI','FIN','246','ຟິນແລນ','Finland',TRUE),
('FJ','FJI','242','Fiji','Fiji',TRUE),
('FK','FLK','238','Falkland Islands (Malvinas)','Falkland Islands (Malvinas)',TRUE),
('FM','FSM','583','Micronesia, Federated States of','Micronesia, Federated States of',TRUE),
('FO','FRO','234','Faroe Islands','Faroe Islands',TRUE),
('FR','FRA','250','ຝຣັ່ງ','France',TRUE),
('GA','GAB','266','Gabon','Gabon',TRUE),
('GB','GBR','826','ອັງກິດ','United Kingdom',TRUE),
('GD','GRD','308','Grenada','Grenada',TRUE),
('GE','GEO','268','Georgia','Georgia',TRUE),
('GF','GUF','254','French Guiana','French Guiana',TRUE),
('GG','GGY','831','Guernsey','Guernsey',TRUE),
('GH','GHA','288','Ghana','Ghana',TRUE),
('GI','GIB','292','Gibraltar','Gibraltar',TRUE),
('GL','GRL','304','Greenland','Greenland',TRUE),
('GM','GMB','270','Gambia','Gambia',TRUE),
('GN','GIN','324','Guinea','Guinea',TRUE),
('GP','GLP','312','Guadeloupe','Guadeloupe',TRUE),
('GQ','GNQ','226','Equatorial Guinea','Equatorial Guinea',TRUE),
('GR','GRC','300','ກຣີສ','Greece',TRUE),
('GS','SGS','239','South Georgia and the South Sandwich Islands','South Georgia and the South Sandwich Islands',TRUE),
('GT','GTM','320','Guatemala','Guatemala',TRUE),
('GU','GUM','316','Guam','Guam',TRUE),
('GW','GNB','624','Guinea-Bissau','Guinea-Bissau',TRUE),
('GY','GUY','328','Guyana','Guyana',TRUE),
('HK','HKG','344','ຮົງກົງ','Hong Kong',TRUE),
('HM','HMD','334','Heard Island and McDonald Islands','Heard Island and McDonald Islands',TRUE),
('HN','HND','340','Honduras','Honduras',TRUE),
('HR','HRV','191','Croatia','Croatia',TRUE),
('HT','HTI','332','Haiti','Haiti',TRUE),
('HU','HUN','348','ຮັງກາຣີ','Hungary',TRUE),
('ID','IDN','360','ອິນໂດເນເຊຍ','Indonesia',TRUE),
('IE','IRL','372','ໄອແລນ','Ireland',TRUE),
('IL','ISR','376','ອິສະຣາແອນ','Israel',TRUE),
('IM','IMN','833','Isle of Man','Isle of Man',TRUE),
('IN','IND','356','ອິນເດຍ','India',TRUE),
('IO','IOT','086','British Indian Ocean Territory','British Indian Ocean Territory',TRUE),
('IQ','IRQ','368','ອີຣັກ','Iraq',TRUE),
('IR','IRN','364','ອີຣ່ານ','Iran, Islamic Republic of',TRUE),
('IS','ISL','352','Iceland','Iceland',TRUE),
('IT','ITA','380','ອິຕາລີ','Italy',TRUE),
('JE','JEY','832','Jersey','Jersey',TRUE),
('JM','JAM','388','Jamaica','Jamaica',TRUE),
('JO','JOR','400','Jordan','Jordan',TRUE),
('JP','JPN','392','ຍີ່ປຸ່ນ','Japan',TRUE),
('KE','KEN','404','Kenya','Kenya',TRUE),
('KG','KGZ','417','Kyrgyzstan','Kyrgyzstan',TRUE),
('KH','KHM','116','ກຳປູເຈຍ','Cambodia',TRUE),
('KI','KIR','296','Kiribati','Kiribati',TRUE),
('KM','COM','174','Comoros','Comoros',TRUE),
('KN','KNA','659','Saint Kitts and Nevis','Saint Kitts and Nevis',TRUE),
('KP','PRK','408','ເກົາຫຼີເໜືອ','Korea, Democratic People''s Republic of',TRUE),
('KR','KOR','410','ເກົາຫຼີໃຕ້','Korea, Republic of',TRUE),
('KW','KWT','414','Kuwait','Kuwait',TRUE),
('KY','CYM','136','Cayman Islands','Cayman Islands',TRUE),
('KZ','KAZ','398','Kazakhstan','Kazakhstan',TRUE),
('LA','LAO','418','ລາວ','Lao People''s Democratic Republic',TRUE),
('LB','LBN','422','Lebanon','Lebanon',TRUE),
('LC','LCA','662','Saint Lucia','Saint Lucia',TRUE),
('LI','LIE','438','Liechtenstein','Liechtenstein',TRUE),
('LK','LKA','144','ສີລັງກາ','Sri Lanka',TRUE),
('LR','LBR','430','Liberia','Liberia',TRUE),
('LS','LSO','426','Lesotho','Lesotho',TRUE),
('LT','LTU','440','Lithuania','Lithuania',TRUE),
('LU','LUX','442','Luxembourg','Luxembourg',TRUE),
('LV','LVA','428','Latvia','Latvia',TRUE),
('LY','LBY','434','Libya','Libya',TRUE),
('MA','MAR','504','Morocco','Morocco',TRUE),
('MC','MCO','492','Monaco','Monaco',TRUE),
('MD','MDA','498','Moldova, Republic of','Moldova, Republic of',TRUE),
('ME','MNE','499','Montenegro','Montenegro',TRUE),
('MF','MAF','663','Saint Martin (French part)','Saint Martin (French part)',TRUE),
('MG','MDG','450','Madagascar','Madagascar',TRUE),
('MH','MHL','584','Marshall Islands','Marshall Islands',TRUE),
('MK','MKD','807','North Macedonia','North Macedonia',TRUE),
('ML','MLI','466','Mali','Mali',TRUE),
('MM','MMR','104','ມຽນມາ','Myanmar',TRUE),
('MN','MNG','496','ມົງໂກເລຍ','Mongolia',TRUE),
('MO','MAC','446','ມາເກົ໊ະ','Macao',TRUE),
('MP','MNP','580','Northern Mariana Islands','Northern Mariana Islands',TRUE),
('MQ','MTQ','474','Martinique','Martinique',TRUE),
('MR','MRT','478','Mauritania','Mauritania',TRUE),
('MS','MSR','500','Montserrat','Montserrat',TRUE),
('MT','MLT','470','Malta','Malta',TRUE),
('MU','MUS','480','Mauritius','Mauritius',TRUE),
('MV','MDV','462','Maldives','Maldives',TRUE),
('MW','MWI','454','Malawi','Malawi',TRUE),
('MX','MEX','484','ແມັກຊິໂກ','Mexico',TRUE),
('MY','MYS','458','ມາເລເຊຍ','Malaysia',TRUE),
('MZ','MOZ','508','Mozambique','Mozambique',TRUE),
('NA','NAM','516','Namibia','Namibia',TRUE),
('NC','NCL','540','New Caledonia','New Caledonia',TRUE),
('NE','NER','562','Niger','Niger',TRUE),
('NF','NFK','574','Norfolk Island','Norfolk Island',TRUE),
('NG','NGA','566','Nigeria','Nigeria',TRUE),
('NI','NIC','558','Nicaragua','Nicaragua',TRUE),
('NL','NLD','528','ໂຮນລັງ','Netherlands',TRUE),
('NO','NOR','578','ນໍເວ','Norway',TRUE),
('NP','NPL','524','ເນປານ','Nepal',TRUE),
('NR','NRU','520','Nauru','Nauru',TRUE),
('NU','NIU','570','Niue','Niue',TRUE),
('NZ','NZL','554','ນິວຊີແລນ','New Zealand',TRUE),
('OM','OMN','512','Oman','Oman',TRUE),
('PA','PAN','591','Panama','Panama',TRUE),
('PE','PER','604','Peru','Peru',TRUE),
('PF','PYF','258','French Polynesia','French Polynesia',TRUE),
('PG','PNG','598','Papua New Guinea','Papua New Guinea',TRUE),
('PH','PHL','608','ຟີລິບປິນ','Philippines',TRUE),
('PK','PAK','586','ປາກີສະຖານ','Pakistan',TRUE),
('PL','POL','616','ໂປແລນ','Poland',TRUE),
('PM','SPM','666','Saint Pierre and Miquelon','Saint Pierre and Miquelon',TRUE),
('PN','PCN','612','Pitcairn','Pitcairn',TRUE),
('PR','PRI','630','Puerto Rico','Puerto Rico',TRUE),
('PS','PSE','275','Palestine, State of','Palestine, State of',TRUE),
('PT','PRT','620','ປອກຕຸຍການ','Portugal',TRUE),
('PW','PLW','585','Palau','Palau',TRUE),
('PY','PRY','600','Paraguay','Paraguay',TRUE),
('QA','QAT','634','Qatar','Qatar',TRUE),
('RE','REU','638','Réunion','Réunion',TRUE),
('RO','ROU','642','ໂຣມາເນຍ','Romania',TRUE),
('RS','SRB','688','Serbia','Serbia',TRUE),
('RU','RUS','643','ຣັດເຊຍ','Russian Federation',TRUE),
('RW','RWA','646','Rwanda','Rwanda',TRUE),
('SA','SAU','682','ຊາອຸດີອາຣະເບຍ','Saudi Arabia',TRUE),
('SB','SLB','090','Solomon Islands','Solomon Islands',TRUE),
('SC','SYC','690','Seychelles','Seychelles',TRUE),
('SD','SDN','729','Sudan','Sudan',TRUE),
('SE','SWE','752','ສະວີເດັນ','Sweden',TRUE),
('SG','SGP','702','ສິງກະໂປ','Singapore',TRUE),
('SH','SHN','654','Saint Helena, Ascension and Tristan da Cunha','Saint Helena, Ascension and Tristan da Cunha',TRUE),
('SI','SVN','705','Slovenia','Slovenia',TRUE),
('SJ','SJM','744','Svalbard and Jan Mayen','Svalbard and Jan Mayen',TRUE),
('SK','SVK','703','Slovakia','Slovakia',TRUE),
('SL','SLE','694','Sierra Leone','Sierra Leone',TRUE),
('SM','SMR','674','San Marino','San Marino',TRUE),
('SN','SEN','686','Senegal','Senegal',TRUE),
('SO','SOM','706','Somalia','Somalia',TRUE),
('SR','SUR','740','Suriname','Suriname',TRUE),
('SS','SSD','728','South Sudan','South Sudan',TRUE),
('ST','STP','678','Sao Tome and Principe','Sao Tome and Principe',TRUE),
('SV','SLV','222','El Salvador','El Salvador',TRUE),
('SX','SXM','534','Sint Maarten (Dutch part)','Sint Maarten (Dutch part)',TRUE),
('SY','SYR','760','Syrian Arab Republic','Syrian Arab Republic',TRUE),
('SZ','SWZ','748','Eswatini','Eswatini',TRUE),
('TC','TCA','796','Turks and Caicos Islands','Turks and Caicos Islands',TRUE),
('TD','TCD','148','Chad','Chad',TRUE),
('TF','ATF','260','French Southern Territories','French Southern Territories',TRUE),
('TG','TGO','768','Togo','Togo',TRUE),
('TH','THA','764','ໄທ','Thailand',TRUE),
('TJ','TJK','762','Tajikistan','Tajikistan',TRUE),
('TK','TKL','772','Tokelau','Tokelau',TRUE),
('TL','TLS','626','ຕີມໍເລສະເຕ','Timor-Leste',TRUE),
('TM','TKM','795','Turkmenistan','Turkmenistan',TRUE),
('TN','TUN','788','Tunisia','Tunisia',TRUE),
('TO','TON','776','Tonga','Tonga',TRUE),
('TR','TUR','792','ຕວກກີ','Türkiye',TRUE),
('TT','TTO','780','Trinidad and Tobago','Trinidad and Tobago',TRUE),
('TV','TUV','798','Tuvalu','Tuvalu',TRUE),
('TW','TWN','158','ໄຕ້ຫວັນ','Taiwan, Province of China',TRUE),
('TZ','TZA','834','Tanzania, United Republic of','Tanzania, United Republic of',TRUE),
('UA','UKR','804','ຢູເຄຣນ','Ukraine',TRUE),
('UG','UGA','800','Uganda','Uganda',TRUE),
('UM','UMI','581','United States Minor Outlying Islands','United States Minor Outlying Islands',TRUE),
('US','USA','840','ສະຫະລັດອາເມລິກາ','United States',TRUE),
('UY','URY','858','Uruguay','Uruguay',TRUE),
('UZ','UZB','860','Uzbekistan','Uzbekistan',TRUE),
('VA','VAT','336','Holy See (Vatican City State)','Holy See (Vatican City State)',TRUE),
('VC','VCT','670','Saint Vincent and the Grenadines','Saint Vincent and the Grenadines',TRUE),
('VE','VEN','862','Venezuela, Bolivarian Republic of','Venezuela, Bolivarian Republic of',TRUE),
('VG','VGB','092','Virgin Islands, British','Virgin Islands, British',TRUE),
('VI','VIR','850','Virgin Islands, U.S.','Virgin Islands, U.S.',TRUE),
('VN','VNM','704','ຫວຽດນາມ','Viet Nam',TRUE),
('VU','VUT','548','Vanuatu','Vanuatu',TRUE),
('WF','WLF','876','Wallis and Futuna','Wallis and Futuna',TRUE),
('WS','WSM','882','Samoa','Samoa',TRUE),
('YE','YEM','887','Yemen','Yemen',TRUE),
('YT','MYT','175','Mayotte','Mayotte',TRUE),
('ZA','ZAF','710','ອາຟຣິກາໃຕ້','South Africa',TRUE),
('ZM','ZMB','894','Zambia','Zambia',TRUE),
('ZW','ZWE','716','Zimbabwe','Zimbabwe',TRUE);

-- Species — reuses the exact Lao/English labels already live in the
-- provincial-reporting UI (reportingSpeciesOptions() in app.ts), so the
-- whole app shares one species taxonomy instead of a second invented one.
INSERT INTO lookup.species(code,name_lo,name_en,tracking_mode,is_active) VALUES
('BUFFALO','ຄວາຍ','Buffalo','CONFIGURABLE',TRUE),
('CATTLE','ງົວ','Cattle','CONFIGURABLE',TRUE),
('PIG','ໝູ','Pig','CONFIGURABLE',TRUE),
('GOAT_SHEEP','ແກະ/ແບ້','Sheep-Goat','CONFIGURABLE',TRUE),
('POULTRY','ສັດປີກ','Poultry','CONFIGURABLE',TRUE),
('DOG','ໝາ','Dog','CONFIGURABLE',TRUE),
('CAT','ແມວ','Cat','CONFIGURABLE',TRUE),
('HORSE','ມ້າ','Horse','CONFIGURABLE',TRUE),
('AQUATIC','ສັດນ້ຳ','Aquatic','CONFIGURABLE',TRUE),
('OTHER','ອື່ນໆ','Other','CONFIGURABLE',TRUE);

-- Unit of measure — small starter set covering common export item units.
-- Extending this list later is a plain one-line INSERT, no schema change.
INSERT INTO lookup.unit_of_measure(code,name_lo,name_en,dimension_code,is_active) VALUES
('HEAD','ຫົວ','Head','COUNT',TRUE),
('KG','ກິໂລກຣາມ','Kilogram','WEIGHT',TRUE),
('TON','ໂຕນ','Ton','WEIGHT',TRUE),
('LITER','ລິດ','Liter','VOLUME',TRUE),
('PIECE','ອັນ','Piece','COUNT',TRUE),
('BOX','ກ່ອງ','Box','COUNT',TRUE),
('EGG','ໜ່ວຍ','Egg','COUNT',TRUE),
('DOSE','ໂດສ','Dose','COUNT',TRUE);

-- ============================================================================
-- MIGRATION: 000900_tr2001_service_registration.sql
-- ============================================================================
-- ============================================================================
-- LVSP Migration 000900 — TR-2001 Export Application: Guided Service Registration
-- ============================================================================
-- ຈຸດປະສົງ: ລົງທະບຽນ "ຄຳຮ້ອງສົ່ງອອກ" (TR-2001) ເປັນ guided service ໃໝ່
-- ໃນລະບົບ Guided Services ທີ່ມີຢູ່ແລ້ວ (system.service_definition /
-- service_version / service_guide / service_step). ນີ້ແມ່ນຂໍ້ມູນ config
-- ລ້ວນໆ (DATA-ONLY) — ບໍ່ມີ CREATE TABLE / ALTER / DROP.
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-16):
--   * ໃຊ້ຕາຕະລາງ system.service_* ທີ່ມີຢູ່ແລ້ວ, ຄືຮູບແບບດຽວກັບ
--     TR-1007 / TR-1021 / VM-1003 (ຢືນຢັນຄໍລໍາຄົບຖ້ວນ ແລະ ຮູບແບບແຖວຈິງ
--     ຂອງ TR-1007 ຈາກ Round 9 audit, 2026-09-16 — ບໍ່ໄດ້ເດົາ column ໃດເລີຍ).
--   * launch_module_key='export_applications' — ໂຫຼດ module ໃໝ່ໃນ app.ts
--     (ແຍກ patch, ບໍ່ຢູ່ໃນ migration ນີ້).
--   * service_version.status='DRAFT' ຄືກັນກັບ TR-1007/TR-1021/VM-1003
--     (ຮູບແບບປົກກະຕິ — ຍັງບໍ່ແມ່ນ production-signed workflow).
--   * service_guide.status='PILOT' ຄືກັນກັບ TR-1007.
--   * 5 service_step (ບໍ່ແມ່ນ 8 ແບບ TR-1007) — scope ຂອງ milestone ນີ້ຈຳກັດ
--     ພຽງ wizard + submit, ບໍ່ມີ SYSTEM_CHECK/DOCUMENTS/PROCESSING step ຍັງ
--     (ເພີ່ມພາຍຫຼັງໄດ້ໂດຍ service_version ໃໝ່, ບໍ່ແກ້ແຖວນີ້).
--   * step_type/actor_scope ທຸກຄ່າແມ່ນຄ່າທີ່ໃຊ້ຢູ່ແລ້ວໃນລະບົບ (ຢືນຢັນຈາກ
--     Round 8/9 audit): GUIDANCE/FORM/ITEMS/REVIEW/DECLARATION, APPLICANT.
--   * ບໍ່ມີ service_requirement/service_output row ຍັງ (ໃບຢັ້ງຢືນ/ເອກະສານ
--     ປະກອບ ເປັນ milestone ພາຍຫຼັງ).
--   * ໃຊ້ chained writable-CTE ດຽວ (WITH svc/ver/guide ... INSERT INTO
--     service_step) ເພື່ອບໍ່ຕ້ອງໃຊ້ uuid ທີ່ເດົາ — id ຂອງແຖວທີ່ຫາກໍ່ insert
--     ຖືກສົ່ງຕໍ່ໂດຍກົງຜ່ານ RETURNING/SELECT, ບໍ່ມີ hard-coded uuid ໃນໄຟລ໌ນີ້.
--
-- ອ້າງອີງ: claude/LVSP_EXPORT_WIZARD_IMPLEMENTATION_PLAN.md (v2, ອະນຸມັດແລ້ວ)
--          case_no format ອະນຸມັດແລ້ວ: EXP-2026-000001 (internal/system
--          reference number ເທົ່ານັ້ນ, ບໍ່ແມ່ນເລກໃບຢັ້ງຢືນ/ໃບອະນຸຍາດທາງການ —
--          ບໍ່ໄດ້ຖືກ hard-code ຢູ່ບ່ອນໃດໃນ migration ນີ້; ເລກຈິງຖືກອອກຕອນ
--          runtime ຈາກ system.number_sequence, ບໍ່ແມ່ນຈາກ migration).
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction
-- control ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
--
-- ສະຖານະ (2026-09-16): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ຍັງບໍ່ໄດ້ apply ລົງ Neon.
-- ============================================================================

WITH svc AS (
    INSERT INTO system.service_definition
        (service_code, domain_code, name_lo, name_en, description, applicant_type, is_public, is_active)
    VALUES (
        'TR-2001',
        'TR',
        'ຄຳຮ້ອງສົ່ງອອກ',
        'Export Application',
        'Guided wizard to submit an export application: destination country, intended shipment window, and one or more commodity items in a single submission.',
        'COMPANY',
        true,
        true
    )
    RETURNING id
), ver AS (
    INSERT INTO system.service_version
        (service_id, version_no, effective_from, workflow_code, status)
    SELECT id, 1, now(), NULL, 'DRAFT'
    FROM svc
    RETURNING id
), guide AS (
    INSERT INTO system.service_guide
        (service_version_id, category_code, icon, display_order,
         overview_lo, overview_en,
         eligibility_lo, eligibility_en,
         preparation_lo, preparation_en,
         processing_lo, processing_en,
         launch_module_key, launch_action,
         allow_public_browse, requires_authentication,
         configuration_notice_lo, configuration_notice_en,
         status)
    SELECT
        id,
        'TRADE',
        '📦',
        35,
        'ຄຳຮ້ອງສົ່ງອອກ 1 ໃບສາມາດມີຫຼາຍລາຍການສິນຄ້າ. ລະບົບຈະສ້າງເລກອ້າງອີງພາຍໃນ ແລະ ບັນທຶກຄຳຮ້ອງເປັນສະຖານະ SUBMITTED ທັນທີ.',
        'One export application may contain multiple commodity items. LVSP issues an internal reference number and records the application as SUBMITTED immediately.',
        'ກ່ອນຍື່ນ ກວດ Company, ປະເທດປາຍທາງ ແລະ ຂໍ້ມູນສິນຄ້າ (ຊະນິດພັນ/ຈຳນວນ/ຫົວໜ່ວຍ).',
        'Before submission, confirm the company, destination country and item details (species/quantity/unit).',
        'ກະກຽມຂໍ້ມູນບໍລິສັດ, ປະເທດປາຍທາງ, ໄລຍະເວລາຂົນສົ່ງ ແລະ ລາຍການສິນຄ້າ (ສາມາດເພີ່ມໄດ້ຫຼາຍລາຍການ).',
        'Prepare company details, destination country, the intended shipment window and item details (multiple items can be added).',
        'ຫຼັງຍື່ນ, ຄຳຮ້ອງຈະຖືກບັນທຶກເປັນສະຖານະ SUBMITTED ພ້ອມເລກອ້າງອີງພາຍໃນ. ຂັ້ນຕອນ Permit/Shipment/Health Certificate/e-Cert ຈະເພີ່ມພາຍຫຼັງໃນ milestone ຕໍ່ໄປ.',
        'After submission, the application is recorded as SUBMITTED with an internal reference number. Permit/Shipment/Health Certificate/e-Cert steps are added in a later milestone.',
        'export_applications',
        'CREATE',
        true,
        true,
        'ຂໍ້ກຳນົດ/ຂັ້ນຕອນໃນໜ້ານີ້ແມ່ນ configuration ສຳລັບ Staging/Pilot (wizard + submit ເທົ່ານັ້ນ). Permit/Shipment/Health Certificate/e-Cert ຍັງບໍ່ໄດ້ຮວມຢູ່ milestone ນີ້.',
        'Requirements/steps shown here are staging/pilot configuration (wizard + submit only). Permit/Shipment/Health Certificate/e-Cert are not part of this milestone.',
        'PILOT'
    FROM ver
    RETURNING id
)
INSERT INTO system.service_step
    (service_version_id, step_code, sequence_no, name_lo, name_en, description_lo, description_en, step_type, actor_scope, is_required, configuration, status)
SELECT
    ver.id, x.step_code, x.sequence_no, x.name_lo, x.name_en, x.description_lo, x.description_en, x.step_type, 'APPLICANT', true, '{}'::jsonb, 'ACTIVE'
FROM ver
CROSS JOIN guide
CROSS JOIN (VALUES
    ('BEFORE_START',       10, 'ກວດຄວາມພ້ອມ',        'Before you start',
        'ກວດ Company ແລະ ຂໍ້ມູນປະເທດປາຍທາງກ່ອນເລີ່ມ.',
        'Confirm company details and destination country before starting.',
        'GUIDANCE'),
    ('APPLICATION_HEADER', 20, 'ຂໍ້ມູນຄຳຮ້ອງ',        'Application header',
        'ເລືອກ Company, ປະເພດບໍລິການ, ປະເທດປາຍທາງ ແລະ ໄລຍະເວລາຂົນສົ່ງ.',
        'Select company, work area, destination country and the intended shipment window.',
        'FORM'),
    ('ITEMS',              30, 'ລາຍການສິນຄ້າ',        'Items',
        'ເພີ່ມລາຍການສິນຄ້າ (ຊະນິດພັນ/ຈຳນວນ/ຫົວໜ່ວຍ) — ສາມາດເພີ່ມໄດ້ຫຼາຍລາຍການ.',
        'Add commodity items (species/quantity/unit) — multiple items may be added.',
        'ITEMS'),
    ('REVIEW',             40, 'ກວດທານກ່ອນສົ່ງ',       'Review',
        'ກວດຂໍ້ມູນຄຳຮ້ອງ ແລະ ລາຍການທັງໝົດກ່ອນຍື່ນ.',
        'Review the application and all items before submission.',
        'REVIEW'),
    ('SUBMIT',             50, 'ຢືນຢັນ ແລະ ສົ່ງຄຳຮ້ອງ', 'Confirm and submit',
        'ຢືນຢັນ ແລະ ສົ່ງຄຳຮ້ອງ — ລະບົບຈະອອກເລກອ້າງອີງພາຍໃນທັນທີ.',
        'Confirm and submit — the system issues an internal reference number immediately.',
        'DECLARATION')
) AS x(step_code, sequence_no, name_lo, name_en, description_lo, description_en, step_type);

-- ============================================================================
-- END 000900 — 0 CREATE TABLE, 0 ALTER, 0 DROP, 1 service_definition,
-- 1 service_version, 1 service_guide, 5 service_step. DATA-ONLY.
-- ============================================================================

-- ============================================================================
-- MIGRATION: 000910_vetdrug_combined_herbal_amr.sql
-- ============================================================================
-- ============================================================================
-- LVSP Migration 000910 — Vet Drug: Combined Packaging Mode + Herbal Category + AMR/WOAH classification
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມ 3 ຄວາມສາມາດໃໝ່ໃສ່ Veterinary Drug Registration ແບບ ADDITIVE
-- ລ້ວນໆ (ບໍ່ແກ້/ບໍ່ລຶບຄໍລຳເກົ່າ, ບໍ່ກະທົບ 26 ແຖວທະບຽນຢາທີ່ມີຢູ່ແລ້ວ):
--   1. size_mode ('single'/'combined'/'multi') ໃສ່ product.product_regulatory_profile
--      — NULL ສຳລັບ 26 ແຖວເກົ່າ (ຖືວ່າ "legacy", app code fallback ໄປໃຊ້
--      ພຶດຕິກຳ total>1 ເກົ່າ), ບັງຄັບເລືອກສະເພາະແຖວໃໝ່ (ບັງຄັບຢູ່ໃນ code, ບໍ່ແມ່ນ
--      NOT NULL constraint — ອະນຸມັດໂດຍ Lee 2026-09-22).
--   2. am_class / am_importance / am_growth_promoter (AMR/WOAH classification,
--      am_importance ຈຳກັດ 3 ຄ່າ VCIA/VHIA/VIA) ໃສ່ product_regulatory_profile
--      — ທັງໝົດ nullable, ໃຊ້ສະເພາະເມື່ອ category = ANTIMICROBIAL (ບັງຄັບຢູ່ໃນ
--      frontend, ບໍ່ແມ່ນ DB constraint, ຄືຮູບແບບດຽວກັບ ATCvet-by-category ທີ່ມີແລ້ວ).
--   3. product.product_common_composition (ຕາຕະລາງໃໝ່) — ສູດປະສົມຮ່ວມກັນ 1 ອັນ
--      ຕໍ່ product ສຳລັບ "combined" mode (ຫຼາຍຂະໜາດບັນຈຸ ໃຊ້ສູດດຽວກັນ) — mirrors
--      product.package_composition's columns ແຕ່ຜູກກັບ product_id ໂດຍກົງ
--      (ບໍ່ຜູກກັບ package_version_id) ເພາະ combined mode ບໍ່ມີສູດແຍກຕໍ່ package.
--   4. 1 ແຖວອ້າງອີງໃໝ່ໃສ່ lookup.veterinary_drug_reference_term: ໝວດ Herbal /
--      Traditional Medicine (domain_code='CATEGORY', code='HERBAL_TRADITIONAL').
--
-- ຫຼັກການອອກແບບ (ອະນຸມັດແລ້ວໂດຍ Lee, 2026-09-22 + ຢືນຢັນ code ຈິງ Round 6/7/8,
-- 2026-09-28 — ບໍ່ໄດ້ເດົາ column/ຕາຕະລາງໃດເລີຍ, ທຸກຄ່າອີງ audit ຈິງ):
--   * source_system/source_reference ຂອງແຖວ Herbal ໃໝ່ ໃຊ້ຄ່າດຽວກັບແຖວ CATEGORY
--     ອື່ນທີ່ມີຢູ່ແລ້ວ ('LVSP_LEGACY'/'admin(4) controlled vocabulary') — ແກ້ໄຂຈາກ
--     ຄ່າທີ່ຮ່າງໄວ້ກ່ອນໜ້ານີ້ໃນ SQL Code Review doc (ພົບຄວາມບໍ່ຕົງກັນ Round 6).
--   * sort_order ຄິດໄລ່ອັດຕະໂນມັດ (MAX+1 ພາຍໃນ domain_code='CATEGORY') ແທນຄ່າ
--     hard-code — ບໍ່ຮູ້ຄ່າ sort_order ປັດຈຸບັນຂອງ 8 ໝວດທີ່ມີຢູ່ແລ້ວແທ້ 100%.
--   * product_common_composition.product_id ອ້າງອີງ product.product(id) ດ້ວຍ
--     ຮູບແບບດຽວກັບ product.package.product_id ທີ່ມີຢູ່ແລ້ວ (ຢືນຢັນຈາກ code ຈິງ
--     ໃນ postgres-store.ts: `select * from product.package where product_id=$1`).
--   * ທຸກ ALTER/CREATE ໃຊ້ IF NOT EXISTS — ປອດໄພຮັນຊ້ຳໄດ້ (ຄືກັບ DRYRUN pattern
--     ຂອງທຸກ migration ກ່ອນໜ້ານີ້ໃນໂຄງການນີ້).
--   * ບໍ່ມີ DROP/RENAME/DELETE ຢູ່ບ່ອນໃດເລີຍໃນໄຟລ໌ນີ້.
--
-- ອ້າງອີງ: claude/LVSP_VETDRUG_COMBINED_HERBAL_IMPLEMENTATION_PLAN.md (ອະນຸມັດແລ້ວ),
--          claude/LVSP_VETDRUG_COMBINED_HERBAL_SQL_CODE_REVIEW.md (ອະນຸມັດແລ້ວ,
--          ຍົກເວັ້ນ source_system/source_reference ທີ່ແກ້ໄຂໃນໄຟລ໌ນີ້).
--
-- ໝາຍເຫດ: ໄຟລ໌ນີ້ບໍ່ມີ BEGIN/COMMIT ຂອງມັນເອງໂດຍເຈດຕະນາ — transaction control
-- ຖືກຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps ໃນ BEGIN...ROLLBACK,
-- scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວຕອນ apply ຈິງ).
--
-- ສະຖານະ (2026-09-28): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ຍັງບໍ່ໄດ້ apply ລົງ Neon. ໜ້າ UI/code patch (app.ts) ຍັງແຍກຕ່າງຫາກ, ຍັງບໍ່ຂຽນ.
-- ============================================================================

-- 1) size_mode + AMR/WOAH classification columns on product.product_regulatory_profile
ALTER TABLE product.product_regulatory_profile
    ADD COLUMN IF NOT EXISTS size_mode text,
    ADD COLUMN IF NOT EXISTS am_class text,
    ADD COLUMN IF NOT EXISTS am_importance text,
    ADD COLUMN IF NOT EXISTS am_growth_promoter boolean;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'product_regulatory_profile_am_importance_check'
    ) THEN
        ALTER TABLE product.product_regulatory_profile
            ADD CONSTRAINT product_regulatory_profile_am_importance_check
            CHECK (am_importance IN ('VCIA','VHIA','VIA') OR am_importance IS NULL);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'product_regulatory_profile_size_mode_check'
    ) THEN
        ALTER TABLE product.product_regulatory_profile
            ADD CONSTRAINT product_regulatory_profile_size_mode_check
            CHECK (size_mode IN ('single','combined','multi') OR size_mode IS NULL);
    END IF;
END $$;

-- 2) New table: shared/common composition for "combined" packaging mode
--    (mirrors product.package_composition's columns, FK to product_id instead
--    of package_version_id, since combined mode has ONE formula shared by all
--    pack sizes rather than a per-package formula).
CREATE TABLE IF NOT EXISTS product.product_common_composition (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id        uuid NOT NULL REFERENCES product.product(id),
    sequence_no       integer NOT NULL,
    ingredient_name   text NOT NULL,
    ingredient_role   character varying NOT NULL,
    quantity_text     text,
    unit_text         text,
    part_text         text,
    equivalence_text  text,
    created_at        timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_common_composition_product_id
    ON product.product_common_composition(product_id);

-- 3) New reference-vocabulary row: Herbal / Traditional Medicine category
--    (idempotent — safe to re-run; sort_order computed, not hard-coded;
--    source_system/source_reference match the real existing convention).
INSERT INTO lookup.veterinary_drug_reference_term
    (domain_code, code, value_text, name_lo, name_en, sort_order,
     source_system, source_reference, is_active)
SELECT
    'CATEGORY',
    'HERBAL_TRADITIONAL',
    'ຢາສະໝຸນໄພ / ຢາພື້ນເມືອງ (Herbal / Traditional Medicine)',
    'ຢາສະໝຸນໄພ / ຢາພື້ນເມືອງ (Herbal / Traditional Medicine)',
    'Herbal / Traditional Medicine',
    (SELECT COALESCE(MAX(sort_order), 0) + 1
       FROM lookup.veterinary_drug_reference_term
      WHERE domain_code = 'CATEGORY'),
    'LVSP_LEGACY',
    'admin(4) controlled vocabulary',
    true
WHERE NOT EXISTS (
    SELECT 1 FROM lookup.veterinary_drug_reference_term
     WHERE domain_code = 'CATEGORY' AND code = 'HERBAL_TRADITIONAL'
);

-- ============================================================================
-- END 000910 — 0 DROP, 0 RENAME, 0 DELETE. 4 ADD COLUMN (nullable) +
-- 2 CHECK CONSTRAINT (guarded) + 1 CREATE TABLE (new) + 1 CREATE INDEX (new) +
-- 1 INSERT (guarded, idempotent) ໃສ່ reference table. 26 ແຖວທະບຽນຢາເກົ່າ ບໍ່ຖືກແຕະ.
-- ============================================================================

-- ============================================================================
-- MIGRATION: 000920_trade_permit_report_validity_columns.sql
-- ============================================================================
-- ============================================================================
-- LVSP Migration 000920 — Trade Permit Report View: add validity/expiry columns
-- ============================================================================
-- ຈຸດປະສົງ: ເພີ່ມ 2 ຄໍລຳໃໝ່ (valid_from, permit_valid_to) ໃສ່ VIEW
-- analytics.v_veterinary_trade_permit_report ແບບ ADDITIVE ລ້ວນໆ — CREATE OR
-- REPLACE VIEW ໂດຍຄໍລຳເກົ່າທັງໝົດ (21 ຄໍລຳ) ຄົງຢູ່ຄືເກົ່າ 100% ທັງລຳດັບ ແລະ
-- ຊື່ (ຢືນຢັນຈາກ pg_get_viewdef ຈິງ, Round 15, 2026-09-28), ພຽງແຕ່ເພີ່ມ 2
-- ຄໍລຳໃໝ່ຕໍ່ທ້າຍ. ບໍ່ແຕະຕາຕະລາງ trade.import_application ຫຼື
-- trade.import_application_item ເລີຍ — VIEW ອ່ານຄໍລຳ valid_from/permit_valid_to
-- ທີ່ມີຢູ່ແລ້ວໃນ trade.import_application (ຢືນຢັນຈາກ code ຈິງ, Round 10) ເຂົ້າມາ
-- ສະແດງເທົ່ານັ້ນ — ບໍ່ມີ column ໃໝ່ໃນຕາຕະລາງໃດເລີຍ.
--
-- ເຫດຜົນ: ໜ້າ Trade workspace (renderTradeLegacyWorkspace → permitsTab, ໃນ
-- apps/web/src/legacy-workspaces-v16.ts) ດຶງຂໍ້ມູນຈາກ backend endpoint
-- /legacy-parity/reports/trade ເຊິ່ງຮັນ
-- `select * from analytics.v_veterinary_trade_permit_report`
-- (ຢືນຢັນຈາກ apps/api/src/core/legacy-parity.ts, Round 14) — ດັ່ງນັ້ນເພີ່ມ
-- ຄໍລຳໃສ່ VIEW ນີ້ຄືວິທີດຽວທີ່ຕ້ອງແກ້ຝັ່ງ database, ບໍ່ຕ້ອງແກ້ backend code ເລີຍ
-- (select * ຈະດຶງຄໍລຳໃໝ່ອັດຕະໂນມັດ, ແລ້ວ camelCase key conversion ຂອງ API layer
-- ຈະສົ່ງອອກເປັນ validFrom/permitValidTo ໃຫ້ frontend ໂດຍອັດຕະໂນມັດ).
--
-- ອະນຸມັດ: Lee ເລືອກ "ໜ້າຕິດຕາມອາຍຸໃບ" ເປັນລຳດັບ 1 ໃນ 4 ຈຸດ (2026-09-28), ອີງ
-- Round 10-15 ຂອງ audit ຊຸດ LVSP_IMPORTEXPORT_AUDIT (ບໍ່ໄດ້ເດົາ column ໃດເລີຍ —
-- Round 15 ຢືນຢັນ view ປັດຈຸບັນມີ 21 ຄໍລຳ, ບໍ່ມີ valid_from/permit_valid_to,
-- ອ່ານ pg_get_viewdef ຈິງ).
--
-- ໝາຍເຫດ: ບໍ່ມີ DROP/RENAME/DELETE ຢູ່ບ່ອນໃດເລີຍ. CREATE OR REPLACE VIEW
-- ປອດໄພຮັນຊ້ຳໄດ້ (idempotent) ເພາະ query ດຽວກັນທຸກຄັ້ງ. ບໍ່ມີ BEGIN/COMMIT
-- ຂອງຕົນເອງ — transaction control ຄວບຄຸມໂດຍ script ທີ່ຮັນມັນ (DRYRUN wraps
-- ໃນ BEGIN...ROLLBACK, scripts/db-migrate.mjs wraps ໃນ BEGIN...COMMIT ອັນດຽວ
-- ຕອນ apply ຈິງ) — ຄືຮູບແບບດຽວກັບ migration 000910.
--
-- ສະຖານະ (2026-09-28): ຂຽນແລ້ວ, ລໍ Lee ຮັນ DRYRUN ແລະ ອະນຸມັດ APPLY.
-- ============================================================================

CREATE OR REPLACE VIEW analytics.v_veterinary_trade_permit_report AS
 SELECT ia.id AS application_id,
    ia.application_no,
    ia.permit_no,
    ia.import_type AS movement_type,
    ia.application_date,
    ia.decision_date,
    ia.cleared_date,
    COALESCE(c.legal_name_lo, c.legal_name_en) AS operator_name,
    ia.origin_country,
    ia.destination_country,
    ia.border_checkpoint,
    ia.checkpoint_out,
    ia.transport_mode,
    count(i.id)::integer AS item_count,
    COALESCE(sum(i.requested_quantity), 0::numeric) AS requested_quantity,
    COALESCE(sum(COALESCE(i.cleared_packs, i.cleared_quantity, 0::numeric)), 0::numeric) AS total_packs,
    COALESCE(sum(i.item_value), 0::numeric) AS total_value,
    COALESCE(sum(i.active_substance_kg), 0::numeric) AS amr_kg,
    ia.status,
    ia.created_at,
    ia.updated_at,
    ia.valid_from,
    ia.permit_valid_to
   FROM trade.import_application ia
     LEFT JOIN master.company c ON c.party_id = ia.company_id
     LEFT JOIN trade.import_application_item i ON i.application_id = ia.id
  GROUP BY ia.id, ia.application_no, ia.permit_no, ia.import_type, ia.application_date, ia.decision_date, ia.cleared_date, c.legal_name_lo, c.legal_name_en, ia.origin_country, ia.destination_country, ia.border_checkpoint, ia.checkpoint_out, ia.transport_mode, ia.status, ia.created_at, ia.updated_at, ia.valid_from, ia.permit_valid_to;

-- ============================================================================
-- END 000920 — 0 DROP, 0 RENAME, 0 DELETE. 1 CREATE OR REPLACE VIEW
-- (21 ຄໍລຳເກົ່າ ຄົງຄືເກົ່າ 100% + 2 ຄໍລຳໃໝ່ຕໍ່ທ້າຍ = 23 ຄໍລຳ). ບໍ່ແຕະຕາຕະລາງໃດເລີຍ.
-- ============================================================================

-- ============================================================================
-- MIGRATION: 000930_department_operations.sql
-- ============================================================================
-- Internal departmental work and budget tracking, not a regulatory decision engine.
-- Amounts are whole Lao kip; no fees, exchange rates or issuing authority are inferred.
CREATE TABLE IF NOT EXISTS reporting.department_work_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 report_month varchar(7) NOT NULL CHECK (report_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 title varchar(300) NOT NULL, planned_result text NOT NULL DEFAULT '', actual_result text NOT NULL DEFAULT '',
 notes text NOT NULL DEFAULT '', owner_subject text NOT NULL,
 status varchar(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','RETURNED')),
 version integer NOT NULL DEFAULT 1, reviewed_by text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS reporting.department_budget_entry (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 report_month varchar(7) NOT NULL CHECK (report_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 title varchar(300) NOT NULL, currency varchar(3) NOT NULL DEFAULT 'LAK' CHECK (currency='LAK'),
 planned_amount numeric(16,0) NOT NULL DEFAULT 0 CHECK (planned_amount>=0 AND planned_amount<=9007199254740991),
 actual_amount numeric(16,0) NOT NULL DEFAULT 0 CHECK (actual_amount>=0 AND actual_amount<=9007199254740991),
 notes text NOT NULL DEFAULT '', owner_subject text NOT NULL,
 status varchar(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','RETURNED')),
 version integer NOT NULL DEFAULT 1, reviewed_by text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_department_work_month ON reporting.department_work_item(report_month,status);
CREATE INDEX IF NOT EXISTS ix_department_budget_month ON reporting.department_budget_entry(report_month,status);

CREATE TRIGGER department_work_no_delete BEFORE DELETE ON reporting.department_work_item FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER department_budget_no_delete BEFORE DELETE ON reporting.department_budget_entry FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER department_work_verified_lock BEFORE UPDATE ON reporting.department_work_item FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('VERIFIED');
CREATE TRIGGER department_budget_verified_lock BEFORE UPDATE ON reporting.department_budget_entry FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('VERIFIED');

-- ============================================================================
-- MIGRATION: 000940_document_intake_pilot.sql
-- ============================================================================
-- Additive upload-first drafts. No official registration/approval is created here.
CREATE TABLE registration.document_intake_draft (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 300),
 owner_id uuid NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','REVIEWED')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 reviewed_fields jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(reviewed_fields)='object'),
 review_note text NOT NULL DEFAULT '',
 ai_extraction jsonb,
 ai_extracted_by uuid REFERENCES security.app_user(id) ON DELETE RESTRICT,
 ai_extracted_at timestamptz,
 reviewed_by uuid REFERENCES security.app_user(id) ON DELETE RESTRICT,
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((status='DRAFT' AND reviewed_by IS NULL AND reviewed_at IS NULL) OR
       (status='REVIEWED' AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX document_intake_owner ON registration.document_intake_draft(owner_id,updated_at DESC);
CREATE TABLE document.intake_attachment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 draft_id uuid NOT NULL REFERENCES registration.document_intake_draft(id) ON DELETE RESTRICT,
 document_id uuid NOT NULL UNIQUE REFERENCES document.document(id) ON DELETE RESTRICT,
 file_id uuid NOT NULL UNIQUE REFERENCES document.file(id) ON DELETE RESTRICT,
 UNIQUE(draft_id,file_id)
);
CREATE INDEX intake_attachment_draft ON document.intake_attachment(draft_id);
CREATE TRIGGER intake_draft_no_delete BEFORE DELETE ON registration.document_intake_draft FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER intake_attachment_no_delete BEFORE DELETE ON document.intake_attachment FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER intake_reviewed_lock BEFORE UPDATE ON registration.document_intake_draft FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('REVIEWED');

-- ============================================================================
-- MIGRATION: 000950_amu_actual_movement_ledger.sql
-- ============================================================================
-- Additive ledger. Registration and legal eligibility remain separate from AMU surveillance.
CREATE TABLE analytics.amu_movement (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 source_key TEXT NOT NULL UNIQUE,
 movement_date DATE NOT NULL,
 movement_type TEXT NOT NULL CHECK(movement_type IN ('IMPORT','EXPORT','RE_EXPORT','TRANSIT')),
 product_id UUID REFERENCES product.product(id) ON DELETE RESTRICT,
 package_id UUID REFERENCES product.package(id) ON DELETE RESTRICT,
 application_item_id UUID REFERENCES trade.import_application_item(id) ON DELETE RESTRICT,
 payload JSONB NOT NULL,
 calculation JSONB NOT NULL,
 status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','REVIEWED','VOID')),
 version INTEGER NOT NULL DEFAULT 1 CHECK(version>0),
 created_by UUID NOT NULL REFERENCES security.app_user(id),
 reviewed_by UUID REFERENCES security.app_user(id),
 review_note TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
