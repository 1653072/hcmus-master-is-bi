-- =============================================================================
-- DDS (Dimensional Data Store) — Galaxy Schema
-- =============================================================================
-- This script runs AFTER 01_create_database.sql on first container startup.
--
-- Purpose in the DWH architecture:
--   Staging (dw-stg-postgres)  →  NDS 3NF (dw-nds-postgres)  →  DDS (this DB)
--
-- DDS holds denormalized dimension + fact tables (Galaxy Schema) optimized for
-- analytics. Hop ETL pipelines will CREATE and LOAD tables here after
-- extracting and transforming data from NDS.
--
-- Consumers:
--   - hop_dds          : read/write — used by Hop DDS load pipelines
--   - analytics_reader : read-only  — used by Power BI (no write access)
--
-- Connection (local dev): localhost:5436 / database dw_dds
-- =============================================================================

\connect dw_dds

-- Isolate non-public DDS objects in a public dedicated schema.
-- Galaxy Schema dimension/fact tables will live under dds_schema.*.
CREATE SCHEMA IF NOT EXISTS dds_schema AUTHORIZATION hop_dds;

-- Default schema for each role so queries can omit the schema prefix.
-- Example: SELECT * FROM dim_movie  instead of  SELECT * FROM dds_schema.dim_movie
ALTER USER hop_dds SET search_path TO dds_schema, public;
ALTER USER analytics_reader SET search_path TO dds_schema, public;

-- analytics_reader: allow analytics_reader to connect to dw_dds database and then read objects in dds_schema.
GRANT CONNECT ON DATABASE dw_dds TO analytics_reader;
GRANT USAGE ON SCHEMA dds_schema TO analytics_reader;

-- Future tables created by hop_dds are automatically readable by Power BI.
-- Without this, analytics_reader would not see tables loaded after init.
ALTER DEFAULT PRIVILEGES FOR ROLE hop_dds IN SCHEMA dds_schema
    GRANT SELECT ON TABLES TO analytics_reader;

-- No dimension/fact tables yet — Hop pipelines will create them during ETL.
-- Expected layout (Galaxy Schema, created later by Hop):
--   dds_schema.dim_movie, dim_user, dim_date, ...
--   dds_schema.fact_rating, fact_revenue, ...
