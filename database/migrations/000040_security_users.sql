CREATE TABLE security.app_user (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), person_party_id UUID REFERENCES master.person(party_id) ON DELETE RESTRICT,
 external_subject TEXT UNIQUE, username CITEXT UNIQUE, email CITEXT, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', last_login_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_app_user_email ON security.app_user(email) WHERE email IS NOT NULL;
CREATE TRIGGER trg_app_user_updated_at BEFORE UPDATE ON security.app_user FOR EACH ROW EXECUTE FUNCTION system.set_updated_at();
