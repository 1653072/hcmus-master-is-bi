\connect dw_nds

CREATE SCHEMA IF NOT EXISTS nds AUTHORIZATION hop_nds;
ALTER USER hop_nds SET search_path TO nds, public;

-- Placeholder schema for Hop NDS load pipelines (3NF target)
