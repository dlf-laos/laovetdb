-- LVSP migration 000001: extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS unaccent;
-- Spatial features. Keep in this migration only when the selected Neon/Postgres environment supports PostGIS.
CREATE EXTENSION IF NOT EXISTS postgis;
