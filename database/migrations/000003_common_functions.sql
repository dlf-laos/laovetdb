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
