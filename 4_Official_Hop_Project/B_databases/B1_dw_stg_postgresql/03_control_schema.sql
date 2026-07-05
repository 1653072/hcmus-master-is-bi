\connect dw_control

CREATE SCHEMA IF NOT EXISTS control AUTHORIZATION hop_control_user;
ALTER USER hop_control_user SET search_path TO control, public;

CREATE TABLE control.etl_extraction_control (
    control_id        SERIAL PRIMARY KEY,
    source_name       VARCHAR(100) NOT NULL,
    table_name        VARCHAR(100) NOT NULL,
    lset              TIMESTAMP,
    cet               TIMESTAMP,
    last_run_status   VARCHAR(20),
    rows_extracted    INTEGER DEFAULT 0,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_etl_extraction_source_table UNIQUE (source_name, table_name)
);

CREATE TABLE control.etl_job_log (
    log_id            SERIAL PRIMARY KEY,
    job_name          VARCHAR(100) NOT NULL,
    source_name       VARCHAR(100),
    started_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at       TIMESTAMP,
    status            VARCHAR(20),
    rows_processed    INTEGER DEFAULT 0,
    error_message     TEXT
);

INSERT INTO control.etl_extraction_control (source_name, table_name, lset, cet, last_run_status, rows_extracted) VALUES
    ('divvy_trips',    'stg_divvy_trips',    '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('citibike_trips', 'stg_citibike_trips', '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('noaa_lcd',       'stg_weather',        '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('gbfs_station',   'stg_gbfs_station',   '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0);

ALTER TABLE control.etl_extraction_control OWNER TO hop_control_user;
ALTER TABLE control.etl_job_log OWNER TO hop_control_user;
