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
