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

CREATE TABLE control.dq_rule_catalog (
    rule_code         VARCHAR(80) PRIMARY KEY,
    source_name       VARCHAR(100) NOT NULL,
    rule_type         VARCHAR(30) NOT NULL,
    severity          VARCHAR(20) NOT NULL,
    rule_description  TEXT NOT NULL,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE control.etl_dq_rule_result (
    result_id         SERIAL PRIMARY KEY,
    load_run_id       VARCHAR(80) NOT NULL,
    source_name       VARCHAR(100) NOT NULL,
    rule_code         VARCHAR(80) NOT NULL,
    rule_type         VARCHAR(30) NOT NULL,
    severity          VARCHAR(20) NOT NULL,
    passed_count      INTEGER NOT NULL DEFAULT 0,
    failed_count      INTEGER NOT NULL DEFAULT 0,
    warning_count     INTEGER NOT NULL DEFAULT 0,
    checked_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dq_rule_result_catalog
        FOREIGN KEY (rule_code) REFERENCES control.dq_rule_catalog (rule_code)
);

INSERT INTO control.etl_extraction_control (source_name, table_name, lset, cet, last_run_status, rows_extracted) VALUES
    ('divvy_trips',    'stg_divvy_trips',    '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('citibike_trips', 'stg_citibike_trips', '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('noaa_lcd',       'stg_weather',        '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0),
    ('gbfs_station',   'stg_gbfs_station',   '2026-01-01 00:00:00', '2026-01-01 00:00:00', 'SUCCESS', 0);

INSERT INTO control.dq_rule_catalog (rule_code, source_name, rule_type, severity, rule_description) VALUES
    ('DIVVY_NULL_REQUIRED',       'divvy_trips',    'null',      'reject',  'ride_id, started_at, and source_city_code are required'),
    ('DIVVY_DUPLICATE_RIDE',      'divvy_trips',    'duplicate', 'reject',  'duplicate source rows by source_city_code + ride_id'),
    ('DIVVY_DATATYPE_TIMESTAMP',  'divvy_trips',    'datatype',  'reject',  'started_at and ended_at must parse as timestamps'),
    ('DIVVY_FORMAT_TRIP_MONTH',   'divvy_trips',    'format',    'reject',  'trip_month must match YYYYMM'),
    ('DIVVY_WARN_STATION_ID',     'divvy_trips',    'null',      'warning', 'missing start/end station id is retained as warning'),
    ('CITI_NULL_REQUIRED',        'citibike_trips', 'null',      'reject',  'ride_id, started_at, and source_city_code are required'),
    ('CITI_DUPLICATE_RIDE',       'citibike_trips', 'duplicate', 'reject',  'duplicate source rows by source_city_code + ride_id'),
    ('CITI_DATATYPE_TIMESTAMP',   'citibike_trips', 'datatype',  'reject',  'started_at and ended_at must parse as timestamps'),
    ('CITI_FORMAT_TRIP_MONTH',    'citibike_trips', 'format',    'reject',  'trip_month must match YYYYMM'),
    ('CITI_WARN_STATION_ID',      'citibike_trips', 'null',      'warning', 'missing start/end station id is retained as warning'),
    ('NOAA_NULL_REQUIRED',        'noaa_lcd',       'null',      'reject',  'station id, observation timestamp, and city are required'),
    ('NOAA_DUPLICATE_HOUR',       'noaa_lcd',       'duplicate', 'reject',  'duplicate source rows by source_city_code + observation_ts'),
    ('NOAA_DATATYPE_NUMERIC',     'noaa_lcd',       'datatype',  'reject',  'temperature, precipitation, and wind speed must be numeric when present'),
    ('NOAA_FORMAT_REPORT_TYPE',   'noaa_lcd',       'format',    'reject',  'report_type must be FM-15, FM-16, or FM-12'),
    ('GBFS_NULL_REQUIRED',        'gbfs_station',   'null',      'reject',  'source_city_code and short_name are required'),
    ('GBFS_DUPLICATE_STATION',    'gbfs_station',   'duplicate', 'reject',  'duplicate source rows by source_city_code + short_name'),
    ('GBFS_DATATYPE_CAPACITY',    'gbfs_station',   'datatype',  'reject',  'capacity must be an integer when present'),
    ('GBFS_FORMAT_COORDINATE',    'gbfs_station',   'format',    'reject',  'latitude and longitude must be in valid coordinate ranges');

ALTER TABLE control.etl_extraction_control OWNER TO hop_control_user;
ALTER TABLE control.etl_job_log OWNER TO hop_control_user;
ALTER TABLE control.dq_rule_catalog OWNER TO hop_control_user;
ALTER TABLE control.etl_dq_rule_result OWNER TO hop_control_user;
