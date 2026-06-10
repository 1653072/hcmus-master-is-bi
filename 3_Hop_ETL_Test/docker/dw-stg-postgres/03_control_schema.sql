\connect dw_control

CREATE SCHEMA IF NOT EXISTS control AUTHORIZATION hop_control;
ALTER USER hop_control SET search_path TO control, public;

CREATE TABLE control.etl_extraction_control (
    source_name       VARCHAR(100) PRIMARY KEY,
    lset              TIMESTAMP,
    cet               TIMESTAMP,
    last_run_status   VARCHAR(20),
    rows_extracted    INTEGER DEFAULT 0,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
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

INSERT INTO control.etl_extraction_control (source_name, lset, cet, last_run_status, rows_extracted) VALUES
    ('ratings_revenues', '2024-06-01 00:00:00', '2024-06-01 00:00:00', 'SUCCESS', 0),
    ('movielens_mongo',  '2024-06-01 00:00:00', '2024-06-01 00:00:00', 'SUCCESS', 0);
