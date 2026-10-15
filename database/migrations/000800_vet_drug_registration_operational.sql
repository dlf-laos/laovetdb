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
