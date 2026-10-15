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
