-- LVSP post-deploy sanity checks. Run after migrations and baseline seeds.
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM system.schema_migration;
    IF v_count <> 90 THEN
        RAISE EXCEPTION 'Expected 90 applied migrations, found %', v_count;
    END IF;

    IF to_regclass('master.party') IS NULL
       OR to_regclass('master.facility') IS NULL
       OR to_regclass('workflow.definition') IS NULL
       OR to_regclass('casework.regulatory_case') IS NULL
       OR to_regclass('registration.registration') IS NULL
       OR to_regclass('licensing.license') IS NULL
       OR to_regclass('inspection.inspection_case') IS NULL
       OR to_regclass('laboratory.sample') IS NULL
       OR to_regclass('animal.animal') IS NULL
       OR to_regclass('disease.disease_case') IS NULL
       OR to_regclass('trade.shipment') IS NULL THEN
        RAISE EXCEPTION 'One or more required LVSP core tables are missing';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pgcrypto')
       OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_trgm')
       OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='citext')
       OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='unaccent')
       OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='postgis') THEN
        RAISE EXCEPTION 'One or more required PostgreSQL extensions are missing';
    END IF;

    IF (SELECT count(*) FROM lookup.admin_unit_type WHERE code IN ('COUNTRY','PROVINCE','DISTRICT','COMMUNE','VILLAGE')) <> 5 THEN
        RAISE EXCEPTION 'Administrative unit type baseline is incomplete';
    END IF;

    IF (SELECT count(*) FROM workflow.definition WHERE workflow_code LIKE 'WF-%') < 12 THEN
        RAISE EXCEPTION 'Workflow family baseline is incomplete';
    END IF;
END;
$$;

SELECT 'applied_migrations' AS check_name, count(*)::text AS value FROM system.schema_migration
UNION ALL SELECT 'schemas', count(*)::text FROM information_schema.schemata WHERE schema_name IN
('system','lookup','master','security','workflow','document','casework','registration','licensing','facility','product','feed','farm','animal','disease','laboratory','fisheries','trade','inspection','compliance','enforcement','notification','integration','gis','analytics','audit')
UNION ALL SELECT 'admin_unit_types', count(*)::text FROM lookup.admin_unit_type
UNION ALL SELECT 'workflow_definitions', count(*)::text FROM workflow.definition
UNION ALL SELECT 'permissions', count(*)::text FROM security.permission
UNION ALL SELECT 'roles', count(*)::text FROM security.role
ORDER BY check_name;
