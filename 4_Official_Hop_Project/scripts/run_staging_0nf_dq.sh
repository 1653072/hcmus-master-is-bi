#!/usr/bin/env bash
set -euo pipefail

STG_CONTAINER="${STG_CONTAINER:-hcmus-bi-official-db-dw-stg-postgres}"
LOAD_RUN_ID="${LOAD_RUN_ID:-bootstrap_202601_202605}"

psql_stg() {
  docker exec -i "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging "$@"
}

psql_control() {
  docker exec -i "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_control "$@"
}

scalar_stg() {
  docker exec "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging -Atc "$1"
}

insert_rule_result() {
  local source_name="$1"
  local rule_code="$2"
  local passed_count="$3"
  local failed_count="$4"
  local warning_count="$5"
  psql_control -c "
INSERT INTO control.etl_dq_rule_result_analysis (
    load_run_id, source_name, rule_code, rule_type, severity,
    passed_count, failed_count, warning_count
)
SELECT
    '${LOAD_RUN_ID}', '${source_name}', rule_code, rule_type, severity,
    ${passed_count}, ${failed_count}, ${warning_count}
FROM control.dq_rule_catalog
WHERE rule_code = '${rule_code}';
"
}

insert_detail_result() {
  local source_name="$1"
  local source_table="$2"
  local rule_code="$3"
  local rule_type="$4"
  local dq_verdict="$5"
  local reason="$6"
  local row_count="$7"
  if [ "${row_count:-0}" -le 0 ]; then
    return
  fi
  psql_control -c "
INSERT INTO control.etl_dq_rule_result_details (
    load_run_id, source_name, source_table, source_file, source_row_number,
    business_key, rule_code, rule_type, dq_verdict, reason, raw_payload
)
VALUES (
    '${LOAD_RUN_ID}', '${source_name}', '${source_table}', NULL, NULL,
    'summary_count=${row_count}', '${rule_code}', '${rule_type}', '${dq_verdict}',
    '${reason}', jsonb_build_object('row_count', ${row_count})
);
"
}

psql_control <<'SQL'
CREATE TABLE IF NOT EXISTS control.dq_rule_catalog (
    rule_code         VARCHAR(80) PRIMARY KEY,
    source_name       VARCHAR(100) NOT NULL,
    rule_type         VARCHAR(30) NOT NULL,
    severity          VARCHAR(20) NOT NULL,
    rule_description  TEXT NOT NULL,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS control.etl_dq_rule_result_analysis (
    result_id         SERIAL PRIMARY KEY,
    load_run_id       VARCHAR(80) NOT NULL,
    source_name       VARCHAR(100) NOT NULL,
    rule_code         VARCHAR(80) NOT NULL,
    rule_type         VARCHAR(30) NOT NULL,
    severity          VARCHAR(20) NOT NULL,
    passed_count      INTEGER NOT NULL DEFAULT 0,
    failed_count      INTEGER NOT NULL DEFAULT 0,
    warning_count     INTEGER NOT NULL DEFAULT 0,
    checked_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS control.etl_dq_rule_result_details (
    detail_id         BIGSERIAL PRIMARY KEY,
    load_run_id       VARCHAR(80) NOT NULL,
    source_name       VARCHAR(100) NOT NULL,
    source_table      VARCHAR(100) NOT NULL,
    source_file       TEXT,
    source_row_number BIGINT,
    business_key      TEXT,
    rule_code         VARCHAR(80) NOT NULL,
    rule_type         VARCHAR(30) NOT NULL,
    dq_verdict        VARCHAR(10) NOT NULL,
    reason            TEXT NOT NULL,
    raw_payload       JSONB,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO control.dq_rule_catalog (rule_code, source_name, rule_type, severity, rule_description) VALUES
    ('DIVVY_NULL_REQUIRED',       'divvy_trips',    'null',      'reject',  'ride_id, started_at, and source_city_code are required'),
    ('DIVVY_DUPLICATE_RIDE',      'divvy_trips',    'duplicate', 'reject',  'duplicate source rows by source_city_code + ride_id'),
    ('DIVVY_DATATYPE_TIMESTAMP',  'divvy_trips',    'datatype',  'reject',  'started_at and ended_at must parse as timestamps'),
    ('DIVVY_FORMAT_TRIP_MONTH',   'divvy_trips',    'format',    'reject',  'trip_month must match YYYYMM'),
    ('DIVVY_REJECT_BOTH_STATION_ID', 'divvy_trips', 'null',      'reject',  'both start_station_id and end_station_id null/blank — keep raw only, exclude from stg'),
    ('DIVVY_WARN_STATION_ID',     'divvy_trips',    'null',      'warning', 'exactly one of start/end station id null/blank — retained in stg with warning'),
    ('CITI_NULL_REQUIRED',        'citibike_trips', 'null',      'reject',  'ride_id, started_at, and source_city_code are required'),
    ('CITI_DUPLICATE_RIDE',       'citibike_trips', 'duplicate', 'reject',  'duplicate source rows by source_city_code + ride_id'),
    ('CITI_DATATYPE_TIMESTAMP',   'citibike_trips', 'datatype',  'reject',  'started_at and ended_at must parse as timestamps'),
    ('CITI_FORMAT_TRIP_MONTH',    'citibike_trips', 'format',    'reject',  'trip_month must match YYYYMM'),
    ('CITI_REJECT_BOTH_STATION_ID', 'citibike_trips', 'null',  'reject',  'both start_station_id and end_station_id null/blank — keep raw only, exclude from stg'),
    ('CITI_WARN_STATION_ID',      'citibike_trips', 'null',      'warning', 'exactly one of start/end station id null/blank — retained in stg with warning'),
    ('NOAA_NULL_REQUIRED',        'noaa_lcd',       'null',      'reject',  'station id, observation timestamp, and city are required'),
    ('NOAA_DUPLICATE_HOUR',       'noaa_lcd',       'duplicate', 'reject',  'duplicate source rows by source_city_code + observation_ts'),
    ('NOAA_DATATYPE_NUMERIC',     'noaa_lcd',       'datatype',  'reject',  'temperature, precipitation, and wind speed must be numeric when present'),
    ('NOAA_FORMAT_REPORT_TYPE',   'noaa_lcd',       'format',    'reject',  'report_type must be FM-15, FM-16, or FM-12'),
    ('GBFS_NULL_REQUIRED',        'gbfs_station',   'null',      'reject',  'source_city_code and short_name are required'),
    ('GBFS_DUPLICATE_STATION',    'gbfs_station',   'duplicate', 'reject',  'duplicate source rows by source_city_code + short_name'),
    ('GBFS_DATATYPE_CAPACITY',    'gbfs_station',   'datatype',  'reject',  'capacity must be an integer when present'),
    ('GBFS_FORMAT_COORDINATE',    'gbfs_station',   'format',    'reject',  'latitude and longitude must be in valid coordinate ranges')
ON CONFLICT (rule_code) DO UPDATE SET
    source_name = EXCLUDED.source_name,
    rule_type = EXCLUDED.rule_type,
    severity = EXCLUDED.severity,
    rule_description = EXCLUDED.rule_description,
    is_active = TRUE;

-- The fallback runs as postgres and may create/migrate control tables on an
-- older dev DB. Keep the Hop control connection as owner for native DQ writes.
ALTER TABLE IF EXISTS control.dq_rule_catalog OWNER TO hop_control_user;
ALTER TABLE IF EXISTS control.etl_dq_rule_result OWNER TO hop_control_user;
ALTER TABLE IF EXISTS control.etl_dq_rule_result_analysis OWNER TO hop_control_user;
ALTER TABLE IF EXISTS control.etl_dq_rule_result_details OWNER TO hop_control_user;
ALTER TABLE IF EXISTS control.etl_extraction_control OWNER TO hop_control_user;
ALTER TABLE IF EXISTS control.etl_job_log OWNER TO hop_control_user;

ALTER SEQUENCE IF EXISTS control.etl_dq_rule_result_result_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_dq_rule_result_analysis_result_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_dq_rule_result_details_detail_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_extraction_control_control_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_job_log_log_id_seq OWNER TO hop_control_user;
SQL

psql_stg <<'SQL'
CREATE TABLE IF NOT EXISTS staging.raw_divvy_trips (
    load_run_id VARCHAR(80) NOT NULL, source_file TEXT, source_row_number BIGINT,
    ride_id TEXT, rideable_type TEXT, started_at TEXT, ended_at TEXT,
    start_station_name TEXT, start_station_id TEXT, end_station_name TEXT, end_station_id TEXT,
    start_lat TEXT, start_lng TEXT, end_lat TEXT, end_lng TEXT,
    member_casual TEXT, source_city_code TEXT, trip_month TEXT,
    raw_loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS staging.raw_citibike_trips (LIKE staging.raw_divvy_trips INCLUDING DEFAULTS);
CREATE TABLE IF NOT EXISTS staging.raw_noaa_weather (
    load_run_id VARCHAR(80) NOT NULL, source_file TEXT, source_row_number BIGINT,
    source_city_code TEXT, noaa_station_id TEXT, observation_ts TEXT, report_type TEXT,
    hourly_dry_bulb_temperature TEXT, hourly_precipitation TEXT, hourly_wind_speed TEXT,
    hourly_present_weather_type TEXT, raw_loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS staging.raw_gbfs_station (
    load_run_id VARCHAR(80) NOT NULL, source_file TEXT, source_row_number BIGINT,
    source_city_code TEXT, gbfs_station_id TEXT, short_name TEXT, station_name TEXT,
    latitude TEXT, longitude TEXT, capacity TEXT, station_type TEXT, region_id TEXT,
    station_status TEXT, operation TEXT, raw_loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS staging.dq_reject_row (
    reject_id BIGSERIAL PRIMARY KEY, load_run_id VARCHAR(80) NOT NULL,
    source_name VARCHAR(100) NOT NULL, source_table VARCHAR(100) NOT NULL,
    source_file TEXT, source_row_number BIGINT, business_key TEXT,
    rule_code VARCHAR(80) NOT NULL, rule_type VARCHAR(30) NOT NULL,
    reject_reason TEXT NOT NULL, raw_payload JSONB,
    rejected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS staging.dq_warning_row (
    warning_id BIGSERIAL PRIMARY KEY, load_run_id VARCHAR(80) NOT NULL,
    source_name VARCHAR(100) NOT NULL, source_table VARCHAR(100) NOT NULL,
    source_file TEXT, source_row_number BIGINT, business_key TEXT,
    rule_code VARCHAR(80) NOT NULL, rule_type VARCHAR(30) NOT NULL,
    warning_reason TEXT NOT NULL, raw_payload JSONB,
    warned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- The fallback runs as postgres and may create raw tables on an older dev DB.
-- Keep the Hop staging connection as their owner so native cleanup can TRUNCATE them.
ALTER TABLE staging.raw_divvy_trips OWNER TO hop_staging_user;
ALTER TABLE staging.raw_citibike_trips OWNER TO hop_staging_user;
ALTER TABLE staging.raw_noaa_weather OWNER TO hop_staging_user;
ALTER TABLE staging.raw_gbfs_station OWNER TO hop_staging_user;

TRUNCATE TABLE
    staging.raw_divvy_trips,
    staging.raw_citibike_trips,
    staging.raw_noaa_weather,
    staging.raw_gbfs_station,
    staging.dq_reject_row,
    staging.dq_warning_row;
SQL

psql_stg -v load_run_id="$LOAD_RUN_ID" <<'SQL'
INSERT INTO staging.raw_divvy_trips (
    load_run_id, source_file, source_row_number,
    ride_id, rideable_type, started_at, ended_at,
    start_station_name, start_station_id, end_station_name, end_station_id,
    start_lat, start_lng, end_lat, end_lng,
    member_casual, source_city_code, trip_month, raw_loaded_at
)
SELECT :'load_run_id', source_file, ROW_NUMBER() OVER (ORDER BY source_file, ride_id),
       ride_id::TEXT, rideable_type::TEXT, started_at::TEXT, ended_at::TEXT,
       start_station_name::TEXT, start_station_id::TEXT, end_station_name::TEXT, end_station_id::TEXT,
       start_lat::TEXT, start_lng::TEXT, end_lat::TEXT, end_lng::TEXT,
       member_casual::TEXT, source_city_code::TEXT, trip_month::TEXT, loaded_at
FROM staging.stg_divvy_trips;

INSERT INTO staging.raw_citibike_trips (
    load_run_id, source_file, source_row_number,
    ride_id, rideable_type, started_at, ended_at,
    start_station_name, start_station_id, end_station_name, end_station_id,
    start_lat, start_lng, end_lat, end_lng,
    member_casual, source_city_code, trip_month, raw_loaded_at
)
SELECT :'load_run_id', source_file, ROW_NUMBER() OVER (ORDER BY source_file, ride_id),
       ride_id::TEXT, rideable_type::TEXT, started_at::TEXT, ended_at::TEXT,
       start_station_name::TEXT, start_station_id::TEXT, end_station_name::TEXT, end_station_id::TEXT,
       start_lat::TEXT, start_lng::TEXT, end_lat::TEXT, end_lng::TEXT,
       member_casual::TEXT, source_city_code::TEXT, trip_month::TEXT, loaded_at
FROM staging.stg_citibike_trips;

INSERT INTO staging.raw_noaa_weather (
    load_run_id, source_file, source_row_number,
    source_city_code, noaa_station_id, observation_ts, report_type,
    hourly_dry_bulb_temperature, hourly_precipitation, hourly_wind_speed,
    hourly_present_weather_type, raw_loaded_at
)
SELECT :'load_run_id', NULL::TEXT, ROW_NUMBER() OVER (ORDER BY source_city_code, observation_ts),
       source_city_code::TEXT, noaa_station_id::TEXT, observation_ts::TEXT, report_type::TEXT,
       hourly_dry_bulb_temperature::TEXT, hourly_precipitation::TEXT, hourly_wind_speed::TEXT,
       hourly_present_weather_type::TEXT, loaded_at
FROM staging.stg_weather;

INSERT INTO staging.raw_gbfs_station (
    load_run_id, source_file, source_row_number,
    source_city_code, gbfs_station_id, short_name, station_name,
    latitude, longitude, capacity, station_type, region_id,
    station_status, operation, raw_loaded_at
)
SELECT :'load_run_id', NULL::TEXT, ROW_NUMBER() OVER (ORDER BY source_city_code, short_name),
       source_city_code::TEXT, gbfs_station_id::TEXT, short_name::TEXT, station_name::TEXT,
       latitude::TEXT, longitude::TEXT, capacity::TEXT, station_type::TEXT, region_id::TEXT,
       station_status::TEXT, operation::TEXT, loaded_at
FROM staging.stg_gbfs_station;
SQL

psql_stg -v load_run_id="$LOAD_RUN_ID" <<'SQL'
INSERT INTO staging.dq_reject_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, reject_reason, raw_payload)
SELECT :'load_run_id', 'divvy_trips', 'raw_divvy_trips', source_file, source_row_number, ride_id,
       'DIVVY_NULL_REQUIRED', 'null', 'ride_id, started_at, and source_city_code are required', to_jsonb(r)
FROM staging.raw_divvy_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NULL OR NULLIF(BTRIM(started_at), '') IS NULL OR NULLIF(BTRIM(source_city_code), '') IS NULL;

INSERT INTO staging.dq_reject_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, reject_reason, raw_payload)
SELECT :'load_run_id', 'citibike_trips', 'raw_citibike_trips', source_file, source_row_number, ride_id,
       'CITI_NULL_REQUIRED', 'null', 'ride_id, started_at, and source_city_code are required', to_jsonb(r)
FROM staging.raw_citibike_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NULL OR NULLIF(BTRIM(started_at), '') IS NULL OR NULLIF(BTRIM(source_city_code), '') IS NULL;

INSERT INTO staging.dq_reject_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, reject_reason, raw_payload)
SELECT :'load_run_id', 'divvy_trips', 'raw_divvy_trips', source_file, source_row_number, ride_id,
       'DIVVY_REJECT_BOTH_STATION_ID', 'null', 'both start_station_id and end_station_id are null', to_jsonb(r)
FROM staging.raw_divvy_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NOT NULL
  AND NULLIF(BTRIM(started_at), '') IS NOT NULL
  AND started_at ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
  AND trip_month IS NOT NULL
  AND trip_month ~ '^[0-9]{6}$'
  AND NULLIF(BTRIM(start_station_id), '') IS NULL
  AND NULLIF(BTRIM(end_station_id), '') IS NULL;

INSERT INTO staging.dq_reject_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, reject_reason, raw_payload)
SELECT :'load_run_id', 'citibike_trips', 'raw_citibike_trips', source_file, source_row_number, ride_id,
       'CITI_REJECT_BOTH_STATION_ID', 'null', 'both start_station_id and end_station_id are null', to_jsonb(r)
FROM staging.raw_citibike_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NOT NULL
  AND NULLIF(BTRIM(started_at), '') IS NOT NULL
  AND started_at ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
  AND trip_month IS NOT NULL
  AND trip_month ~ '^[0-9]{6}$'
  AND NULLIF(BTRIM(start_station_id), '') IS NULL
  AND NULLIF(BTRIM(end_station_id), '') IS NULL;

INSERT INTO staging.dq_warning_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, warning_reason, raw_payload)
SELECT :'load_run_id', 'divvy_trips', 'raw_divvy_trips', source_file, source_row_number, ride_id,
       'DIVVY_WARN_STATION_ID', 'null', 'exactly one of start_station_id / end_station_id is null', to_jsonb(r)
FROM staging.raw_divvy_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NOT NULL
  AND NULLIF(BTRIM(started_at), '') IS NOT NULL
  AND started_at ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
  AND trip_month IS NOT NULL
  AND trip_month ~ '^[0-9]{6}$'
  AND (
        (NULLIF(BTRIM(start_station_id), '') IS NULL AND NULLIF(BTRIM(end_station_id), '') IS NOT NULL)
     OR (NULLIF(BTRIM(start_station_id), '') IS NOT NULL AND NULLIF(BTRIM(end_station_id), '') IS NULL)
      );

INSERT INTO staging.dq_warning_row (load_run_id, source_name, source_table, source_file, source_row_number, business_key, rule_code, rule_type, warning_reason, raw_payload)
SELECT :'load_run_id', 'citibike_trips', 'raw_citibike_trips', source_file, source_row_number, ride_id,
       'CITI_WARN_STATION_ID', 'null', 'exactly one of start_station_id / end_station_id is null', to_jsonb(r)
FROM staging.raw_citibike_trips r
WHERE NULLIF(BTRIM(ride_id), '') IS NOT NULL
  AND NULLIF(BTRIM(started_at), '') IS NOT NULL
  AND started_at ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
  AND trip_month IS NOT NULL
  AND trip_month ~ '^[0-9]{6}$'
  AND (
        (NULLIF(BTRIM(start_station_id), '') IS NULL AND NULLIF(BTRIM(end_station_id), '') IS NOT NULL)
     OR (NULLIF(BTRIM(start_station_id), '') IS NOT NULL AND NULLIF(BTRIM(end_station_id), '') IS NULL)
      );
SQL

psql_control -c "DELETE FROM control.etl_dq_rule_result_details WHERE load_run_id = '${LOAD_RUN_ID}';"
psql_control -c "DELETE FROM control.etl_dq_rule_result_analysis WHERE load_run_id = '${LOAD_RUN_ID}';"

divvy_total="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_divvy_trips;")"
divvy_null="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_reject_row WHERE rule_code = 'DIVVY_NULL_REQUIRED';")"
divvy_dup="$(scalar_stg "SELECT COUNT(*) FROM (SELECT source_city_code, ride_id FROM staging.raw_divvy_trips GROUP BY source_city_code, ride_id HAVING COUNT(*) > 1) d;")"
divvy_bad_month="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_divvy_trips WHERE trip_month !~ '^[0-9]{6}$' OR trip_month IS NULL;")"
divvy_reject_both="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_reject_row WHERE rule_code = 'DIVVY_REJECT_BOTH_STATION_ID';")"
divvy_warn="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_warning_row WHERE rule_code = 'DIVVY_WARN_STATION_ID';")"

citi_total="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_citibike_trips;")"
citi_null="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_reject_row WHERE rule_code = 'CITI_NULL_REQUIRED';")"
citi_dup="$(scalar_stg "SELECT COUNT(*) FROM (SELECT source_city_code, ride_id FROM staging.raw_citibike_trips GROUP BY source_city_code, ride_id HAVING COUNT(*) > 1) d;")"
citi_bad_month="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_citibike_trips WHERE trip_month !~ '^[0-9]{6}$' OR trip_month IS NULL;")"
citi_reject_both="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_reject_row WHERE rule_code = 'CITI_REJECT_BOTH_STATION_ID';")"
citi_warn="$(scalar_stg "SELECT COUNT(*) FROM staging.dq_warning_row WHERE rule_code = 'CITI_WARN_STATION_ID';")"

noaa_total="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_noaa_weather;")"
noaa_null="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_noaa_weather WHERE NULLIF(BTRIM(source_city_code), '') IS NULL OR NULLIF(BTRIM(noaa_station_id), '') IS NULL OR NULLIF(BTRIM(observation_ts), '') IS NULL;")"
noaa_dup="$(scalar_stg "SELECT COUNT(*) FROM (SELECT source_city_code, observation_ts FROM staging.raw_noaa_weather GROUP BY source_city_code, observation_ts HAVING COUNT(*) > 1) d;")"
noaa_bad_report="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_noaa_weather WHERE report_type NOT IN ('FM-15','FM-16','FM-12') OR report_type IS NULL;")"

gbfs_total="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_gbfs_station;")"
gbfs_null="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_gbfs_station WHERE NULLIF(BTRIM(source_city_code), '') IS NULL OR NULLIF(BTRIM(short_name), '') IS NULL;")"
gbfs_dup="$(scalar_stg "SELECT COUNT(*) FROM (SELECT source_city_code, short_name FROM staging.raw_gbfs_station GROUP BY source_city_code, short_name HAVING COUNT(*) > 1) d;")"
gbfs_bad_capacity="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_gbfs_station WHERE capacity IS NOT NULL AND capacity !~ '^[0-9]+$';")"
gbfs_bad_coord="$(scalar_stg "SELECT COUNT(*) FROM staging.raw_gbfs_station WHERE latitude::NUMERIC NOT BETWEEN -90 AND 90 OR longitude::NUMERIC NOT BETWEEN -180 AND 180;")"

insert_rule_result "divvy_trips" "DIVVY_NULL_REQUIRED" "$((divvy_total - divvy_null))" "$divvy_null" 0
insert_rule_result "divvy_trips" "DIVVY_DUPLICATE_RIDE" "$((divvy_total - divvy_dup))" "$divvy_dup" 0
insert_rule_result "divvy_trips" "DIVVY_DATATYPE_TIMESTAMP" "$divvy_total" 0 0
insert_rule_result "divvy_trips" "DIVVY_FORMAT_TRIP_MONTH" "$((divvy_total - divvy_bad_month))" "$divvy_bad_month" 0
insert_rule_result "divvy_trips" "DIVVY_REJECT_BOTH_STATION_ID" "$((divvy_total - divvy_reject_both))" "$divvy_reject_both" 0
insert_rule_result "divvy_trips" "DIVVY_WARN_STATION_ID" "$((divvy_total - divvy_warn))" 0 "$divvy_warn"

insert_rule_result "citibike_trips" "CITI_NULL_REQUIRED" "$((citi_total - citi_null))" "$citi_null" 0
insert_rule_result "citibike_trips" "CITI_DUPLICATE_RIDE" "$((citi_total - citi_dup))" "$citi_dup" 0
insert_rule_result "citibike_trips" "CITI_DATATYPE_TIMESTAMP" "$citi_total" 0 0
insert_rule_result "citibike_trips" "CITI_FORMAT_TRIP_MONTH" "$((citi_total - citi_bad_month))" "$citi_bad_month" 0
insert_rule_result "citibike_trips" "CITI_REJECT_BOTH_STATION_ID" "$((citi_total - citi_reject_both))" "$citi_reject_both" 0
insert_rule_result "citibike_trips" "CITI_WARN_STATION_ID" "$((citi_total - citi_warn))" 0 "$citi_warn"

insert_rule_result "noaa_lcd" "NOAA_NULL_REQUIRED" "$((noaa_total - noaa_null))" "$noaa_null" 0
insert_rule_result "noaa_lcd" "NOAA_DUPLICATE_HOUR" "$((noaa_total - noaa_dup))" "$noaa_dup" 0
insert_rule_result "noaa_lcd" "NOAA_DATATYPE_NUMERIC" "$noaa_total" 0 0
insert_rule_result "noaa_lcd" "NOAA_FORMAT_REPORT_TYPE" "$((noaa_total - noaa_bad_report))" "$noaa_bad_report" 0

insert_rule_result "gbfs_station" "GBFS_NULL_REQUIRED" "$((gbfs_total - gbfs_null))" "$gbfs_null" 0
insert_rule_result "gbfs_station" "GBFS_DUPLICATE_STATION" "$((gbfs_total - gbfs_dup))" "$gbfs_dup" 0
insert_rule_result "gbfs_station" "GBFS_DATATYPE_CAPACITY" "$((gbfs_total - gbfs_bad_capacity))" "$gbfs_bad_capacity" 0
insert_rule_result "gbfs_station" "GBFS_FORMAT_COORDINATE" "$((gbfs_total - gbfs_bad_coord))" "$gbfs_bad_coord" 0

insert_detail_result "divvy_trips" "raw_divvy_trips" "DIVVY_NULL_REQUIRED" "null" "reject" "ride_id, started_at, and source_city_code are required" "$divvy_null"
insert_detail_result "divvy_trips" "raw_divvy_trips" "DIVVY_DUPLICATE_RIDE" "duplicate" "reject" "duplicate source rows by source_city_code and ride_id" "$divvy_dup"
insert_detail_result "divvy_trips" "raw_divvy_trips" "DIVVY_FORMAT_TRIP_MONTH" "format" "reject" "trip_month must match YYYYMM" "$divvy_bad_month"
insert_detail_result "divvy_trips" "raw_divvy_trips" "DIVVY_REJECT_BOTH_STATION_ID" "null" "reject" "both start_station_id and end_station_id are null" "$divvy_reject_both"
insert_detail_result "divvy_trips" "raw_divvy_trips" "DIVVY_WARN_STATION_ID" "null" "warning" "exactly one of start_station_id / end_station_id is null" "$divvy_warn"
insert_detail_result "citibike_trips" "raw_citibike_trips" "CITI_NULL_REQUIRED" "null" "reject" "ride_id, started_at, and source_city_code are required" "$citi_null"
insert_detail_result "citibike_trips" "raw_citibike_trips" "CITI_DUPLICATE_RIDE" "duplicate" "reject" "duplicate source rows by source_city_code and ride_id" "$citi_dup"
insert_detail_result "citibike_trips" "raw_citibike_trips" "CITI_FORMAT_TRIP_MONTH" "format" "reject" "trip_month must match YYYYMM" "$citi_bad_month"
insert_detail_result "citibike_trips" "raw_citibike_trips" "CITI_REJECT_BOTH_STATION_ID" "null" "reject" "both start_station_id and end_station_id are null" "$citi_reject_both"
insert_detail_result "citibike_trips" "raw_citibike_trips" "CITI_WARN_STATION_ID" "null" "warning" "exactly one of start_station_id / end_station_id is null" "$citi_warn"
insert_detail_result "noaa_lcd" "raw_noaa_weather" "NOAA_NULL_REQUIRED" "null" "reject" "station id, observation timestamp, and city are required" "$noaa_null"
insert_detail_result "noaa_lcd" "raw_noaa_weather" "NOAA_DUPLICATE_HOUR" "duplicate" "reject" "duplicate source rows by source_city_code and observation_ts" "$noaa_dup"
insert_detail_result "noaa_lcd" "raw_noaa_weather" "NOAA_FORMAT_REPORT_TYPE" "format" "reject" "report_type must be FM-15, FM-16, or FM-12" "$noaa_bad_report"
insert_detail_result "gbfs_station" "raw_gbfs_station" "GBFS_NULL_REQUIRED" "null" "reject" "source_city_code and short_name are required" "$gbfs_null"
insert_detail_result "gbfs_station" "raw_gbfs_station" "GBFS_DUPLICATE_STATION" "duplicate" "reject" "duplicate source rows by source_city_code and short_name" "$gbfs_dup"
insert_detail_result "gbfs_station" "raw_gbfs_station" "GBFS_DATATYPE_CAPACITY" "datatype" "reject" "capacity must be an integer when present" "$gbfs_bad_capacity"
insert_detail_result "gbfs_station" "raw_gbfs_station" "GBFS_FORMAT_COORDINATE" "format" "reject" "latitude and longitude must be in valid coordinate ranges" "$gbfs_bad_coord"

printf 'load_run_id=%s\n' "$LOAD_RUN_ID"
printf 'raw_divvy=%s raw_citibike=%s raw_noaa=%s raw_gbfs=%s\n' "$divvy_total" "$citi_total" "$noaa_total" "$gbfs_total"
printf 'dq_warnings=%s dq_rejects=%s\n' "$((divvy_warn + citi_warn))" "$((divvy_null + citi_null + divvy_reject_both + citi_reject_both + noaa_null + gbfs_null))"
