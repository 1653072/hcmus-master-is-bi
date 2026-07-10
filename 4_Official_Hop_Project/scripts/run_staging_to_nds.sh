#!/usr/bin/env bash
set -euo pipefail

STG_CONTAINER="${STG_CONTAINER:-hcmus-bi-official-db-dw-stg-postgres}"
NDS_CONTAINER="${NDS_CONTAINER:-hcmus-bi-official-db-dw-nds-postgres}"
ETL_STAGINGDB_TO_NDS_STARTED_AT="$(date '+%Y-%m-%d %H:%M:%S')"

psql_nds() {
  docker exec -i "$NDS_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_nds "$@"
}

psql_control() {
  docker exec -i "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_control "$@"
}

psql_control <<'SQL'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM control.etl_extraction_control
    WHERE source_name IN ('divvy_trips', 'citibike_trips', 'noaa_lcd', 'gbfs_station')
      AND COALESCE(last_run_status, 'FAILED') <> 'SUCCESS'
  ) THEN
    RAISE EXCEPTION 'NDS load blocked: a source-to-staging result is not SUCCESS';
  END IF;
END $$;
SQL

copy_from_stg_to_nds() {
  local select_sql="$1"
  local copy_sql="$2"
  docker exec "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging -c "COPY (${select_sql}) TO STDOUT WITH CSV" \
    | docker exec -i "$NDS_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_nds -c "$copy_sql"
}

psql_nds <<'SQL'
CREATE SCHEMA IF NOT EXISTS import AUTHORIZATION hop_nds_user;

CREATE TABLE IF NOT EXISTS import.stg_gbfs_station (
    source_city_code TEXT,
    short_name TEXT,
    station_name TEXT,
    latitude NUMERIC(12,8),
    longitude NUMERIC(12,8),
    capacity INTEGER,
    station_status TEXT
);

CREATE TABLE IF NOT EXISTS import.stg_weather (
    source_city_code TEXT,
    observation_ts TIMESTAMP,
    report_type TEXT,
    temperature_c NUMERIC(8,2),
    precipitation_mm NUMERIC(10,2),
    wind_speed_ms NUMERIC(8,2),
    present_weather TEXT
);

DO $$
BEGIN
  IF to_regclass('import.stg_trip') IS NULL THEN
    RAISE EXCEPTION 'Missing canonical import.stg_trip buffer; run B2_dw_nds_postgresql/05_import_trip_buffer.sql first';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'import'
      AND c.relname = 'stg_trip'
      AND c.relpersistence <> 'u'
  ) THEN
    RAISE EXCEPTION 'import.stg_trip must be UNLOGGED';
  END IF;
END $$;

TRUNCATE TABLE import.stg_gbfs_station, import.stg_weather, import.stg_trip;
SQL

copy_from_stg_to_nds \
  "SELECT source_city_code, short_name, station_name, latitude, longitude, capacity, station_status FROM staging.stg_gbfs_station" \
  "COPY import.stg_gbfs_station FROM STDIN WITH CSV"

copy_from_stg_to_nds \
  "SELECT source_city_code, observation_ts, report_type, hourly_dry_bulb_temperature, hourly_precipitation, hourly_wind_speed, hourly_present_weather_type FROM staging.stg_weather" \
  "COPY import.stg_weather FROM STDIN WITH CSV"

copy_from_stg_to_nds \
  "SELECT source_city_code, ride_id, rideable_type, started_at, ended_at, start_station_id, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual, trip_month FROM staging.stg_divvy_trips WHERE ride_id IS NOT NULL AND started_at IS NOT NULL UNION ALL SELECT source_city_code, ride_id, rideable_type, started_at, ended_at, start_station_id, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual, trip_month FROM staging.stg_citibike_trips WHERE ride_id IS NOT NULL AND started_at IS NOT NULL" \
  "COPY import.stg_trip FROM STDIN WITH CSV"

psql_nds <<'SQL'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM import.stg_trip
    GROUP BY source_city_code, ride_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate trip keys in import.stg_trip';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM import.stg_trip i
    LEFT JOIN nds.city c ON c.city_code = i.source_city_code
    WHERE c.city_sk IS NULL
  ) THEN
    RAISE EXCEPTION 'Trip buffer contains source_city_code values that do not map to nds.city';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM import.stg_trip
    WHERE source_city_code IS NULL
       OR source_city_code NOT IN ('CHI', 'NYC')
       OR ride_id IS NULL
       OR started_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Trip buffer guard failed: invalid city or required trip key';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM import.stg_trip
    GROUP BY source_city_code, ride_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Trip buffer guard failed: duplicate (source_city_code, ride_id)';
  END IF;
END $$;

INSERT INTO nds.city (
    city_code,
    city_name,
    timezone,
    noaa_station_id,
    gbfs_system_id
)
SELECT DISTINCT
    source_city_code AS city_code,
    CASE source_city_code
        WHEN 'CHI' THEN 'Chicago'
        WHEN 'NYC' THEN 'New York City'
    END AS city_name,
    CASE source_city_code
        WHEN 'CHI' THEN 'America/Chicago'
        WHEN 'NYC' THEN 'America/New_York'
    END AS timezone,
    CASE source_city_code
        WHEN 'CHI' THEN 'USW00014819'
        WHEN 'NYC' THEN 'USW00094728'
    END AS noaa_station_id,
    CASE source_city_code
        WHEN 'CHI' THEN 'divvy'
        WHEN 'NYC' THEN 'citibike'
    END AS gbfs_system_id
FROM (
    SELECT source_city_code FROM import.stg_gbfs_station
    UNION ALL
    SELECT source_city_code FROM import.stg_weather
    UNION ALL
    SELECT source_city_code FROM import.stg_trip
) c
WHERE source_city_code IN ('CHI', 'NYC')
ON CONFLICT (city_code) DO UPDATE SET
    city_name = EXCLUDED.city_name,
    timezone = EXCLUDED.timezone,
    noaa_station_id = EXCLUDED.noaa_station_id,
    gbfs_system_id = EXCLUDED.gbfs_system_id;

WITH date_candidates AS (
    SELECT started_at::DATE AS calendar_date
    FROM import.stg_trip
    WHERE started_at IS NOT NULL
    UNION ALL
    SELECT ended_at::DATE
    FROM import.stg_trip
    WHERE ended_at IS NOT NULL
    UNION ALL
    SELECT observation_ts::DATE
    FROM import.stg_weather
    WHERE observation_ts IS NOT NULL
),
bounds AS (
    SELECT
        MIN(calendar_date) AS start_date,
        MAX(calendar_date) AS end_date
    FROM date_candidates
    HAVING COUNT(calendar_date) > 0
)
INSERT INTO nds.calendar_day (
    calendar_date,
    day_of_week,
    is_weekend,
    month,
    season
)
SELECT
    d::DATE,
    EXTRACT(ISODOW FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d) IN (6, 7),
    EXTRACT(MONTH FROM d)::SMALLINT,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (12, 1, 2) THEN 'winter'
        WHEN EXTRACT(MONTH FROM d) IN (3, 4, 5) THEN 'spring'
        WHEN EXTRACT(MONTH FROM d) IN (6, 7, 8) THEN 'summer'
        ELSE 'fall'
    END
FROM bounds
CROSS JOIN LATERAL generate_series(start_date, end_date, INTERVAL '1 day') AS d
WHERE start_date IS NOT NULL
  AND end_date IS NOT NULL
  AND start_date <= end_date
ON CONFLICT (calendar_date) DO UPDATE SET
    day_of_week = EXCLUDED.day_of_week,
    is_weekend = EXCLUDED.is_weekend,
    month = EXCLUDED.month,
    season = EXCLUDED.season;

UPDATE nds.station s
SET station_name = i.station_name,
    latitude = i.latitude,
    longitude = i.longitude,
    capacity = i.capacity,
    station_status = COALESCE(i.station_status, s.station_status),
    loaded_at = CURRENT_TIMESTAMP
FROM import.stg_gbfs_station i
JOIN nds.city c ON c.city_code = i.source_city_code
WHERE s.city_sk = c.city_sk
  AND s.source_station_id = i.short_name
  AND s.is_current = TRUE;

INSERT INTO nds.station (
    city_sk, source_station_id, station_name, latitude, longitude,
    capacity, station_status, effective_from, row_status, is_current
)
SELECT c.city_sk, i.short_name, i.station_name, i.latitude, i.longitude,
       i.capacity, COALESCE(i.station_status, 'open'), CURRENT_TIMESTAMP, 'active', TRUE
FROM import.stg_gbfs_station i
JOIN nds.city c ON c.city_code = i.source_city_code
WHERE i.short_name IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM nds.station s
      WHERE s.city_sk = c.city_sk
        AND s.source_station_id = i.short_name
        AND s.is_current = TRUE
  );

WITH weather_ranked AS (
    SELECT c.city_sk,
           date_trunc('hour', i.observation_ts) AS observation_hour,
           i.report_type,
           i.temperature_c,
           i.precipitation_mm,
           i.wind_speed_ms,
           i.present_weather,
           CASE
               WHEN UPPER(COALESCE(i.present_weather, '')) LIKE '%SN%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%SG%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%PL%'
                 THEN 'Snow'
               WHEN UPPER(COALESCE(i.present_weather, '')) LIKE '%FG%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%BR%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%HZ%'
                 THEN 'Fog'
               WHEN UPPER(COALESCE(i.present_weather, '')) LIKE '%RA%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%DZ%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%TS%'
                 OR UPPER(COALESCE(i.present_weather, '')) LIKE '%GR%'
                 OR COALESCE(i.precipitation_mm, 0) > 0
                 THEN 'Rain'
               ELSE 'Clear'
           END AS weather_category,
           ROW_NUMBER() OVER (
               PARTITION BY c.city_sk, date_trunc('hour', i.observation_ts)
               ORDER BY
                   CASE i.report_type WHEN 'FM-15' THEN 1 WHEN 'FM-16' THEN 2 WHEN 'FM-12' THEN 3 ELSE 4 END,
                   i.observation_ts
           ) AS rn
    FROM import.stg_weather i
    JOIN nds.city c ON c.city_code = i.source_city_code
    WHERE i.observation_ts IS NOT NULL
)
INSERT INTO nds.weather (
    city_sk, observation_hour, report_type, temperature_c,
    precipitation_mm, wind_speed_ms, present_weather, weather_category
)
SELECT city_sk, observation_hour, report_type, temperature_c,
       precipitation_mm, wind_speed_ms, present_weather, weather_category
FROM weather_ranked
WHERE rn = 1
ON CONFLICT (city_sk, observation_hour) DO UPDATE SET
    report_type = EXCLUDED.report_type,
    temperature_c = EXCLUDED.temperature_c,
    precipitation_mm = EXCLUDED.precipitation_mm,
    wind_speed_ms = EXCLUDED.wind_speed_ms,
    present_weather = EXCLUDED.present_weather,
    weather_category = EXCLUDED.weather_category,
    loaded_at = CURRENT_TIMESTAMP;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM import.stg_trip i
    JOIN nds.city c
      ON c.city_code = i.source_city_code
    JOIN nds.station s
      ON s.city_sk = c.city_sk
     AND s.is_current = TRUE
     AND s.source_station_id IN (i.start_station_id, i.end_station_id)
    GROUP BY c.city_sk, s.source_station_id
    HAVING COUNT(DISTINCT s.station_sk) > 1
  ) THEN
    RAISE EXCEPTION 'Trip merge guard failed: multiple current station rows for a city/station key';
  END IF;
END $$;

INSERT INTO nds.trip (
    city_sk, ride_id, rideable_type, started_at, ended_at,
    start_station_id, end_station_id, start_station_sk, end_station_sk,
    start_lat, start_lng, end_lat, end_lng, member_casual,
    duration_minutes, trip_month
)
SELECT c.city_sk,
       i.ride_id,
       i.rideable_type,
       i.started_at,
       i.ended_at,
       i.start_station_id,
       i.end_station_id,
       ss.station_sk,
       es.station_sk,
       i.start_lat,
       i.start_lng,
       i.end_lat,
       i.end_lng,
       i.member_casual,
       CASE
           WHEN i.started_at IS NOT NULL AND i.ended_at IS NOT NULL AND i.ended_at >= i.started_at
           THEN ROUND((EXTRACT(EPOCH FROM (i.ended_at - i.started_at)) / 60.0)::NUMERIC, 2)
           ELSE NULL
       END AS duration_minutes,
       i.trip_month
FROM import.stg_trip i
JOIN nds.city c ON c.city_code = i.source_city_code
LEFT JOIN nds.station ss
  ON ss.city_sk = c.city_sk
 AND ss.source_station_id = i.start_station_id
 AND ss.is_current = TRUE
LEFT JOIN nds.station es
  ON es.city_sk = c.city_sk
 AND es.source_station_id = i.end_station_id
 AND es.is_current = TRUE
WHERE i.ride_id IS NOT NULL
  AND i.started_at IS NOT NULL
ON CONFLICT (city_sk, ride_id) DO UPDATE SET
    rideable_type = EXCLUDED.rideable_type,
    started_at = EXCLUDED.started_at,
    ended_at = EXCLUDED.ended_at,
    start_station_id = EXCLUDED.start_station_id,
    end_station_id = EXCLUDED.end_station_id,
    start_station_sk = EXCLUDED.start_station_sk,
    end_station_sk = EXCLUDED.end_station_sk,
    start_lat = EXCLUDED.start_lat,
    start_lng = EXCLUDED.start_lng,
    end_lat = EXCLUDED.end_lat,
    end_lng = EXCLUDED.end_lng,
    member_casual = EXCLUDED.member_casual,
    duration_minutes = EXCLUDED.duration_minutes,
    trip_month = EXCLUDED.trip_month,
    loaded_at = CURRENT_TIMESTAMP
WHERE (
    nds.trip.rideable_type,
    nds.trip.started_at,
    nds.trip.ended_at,
    nds.trip.start_station_id,
    nds.trip.end_station_id,
    nds.trip.start_station_sk,
    nds.trip.end_station_sk,
    nds.trip.start_lat,
    nds.trip.start_lng,
    nds.trip.end_lat,
    nds.trip.end_lng,
    nds.trip.member_casual,
    nds.trip.duration_minutes,
    nds.trip.trip_month
) IS DISTINCT FROM (
    EXCLUDED.rideable_type,
    EXCLUDED.started_at,
    EXCLUDED.ended_at,
    EXCLUDED.start_station_id,
    EXCLUDED.end_station_id,
    EXCLUDED.start_station_sk,
    EXCLUDED.end_station_sk,
    EXCLUDED.start_lat,
    EXCLUDED.start_lng,
    EXCLUDED.end_lat,
    EXCLUDED.end_lng,
    EXCLUDED.member_casual,
    EXCLUDED.duration_minutes,
    EXCLUDED.trip_month
);
SQL

staging_to_nds_success_rows="$(docker exec "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging -Atc "
WITH
city_rows AS (
  SELECT COUNT(DISTINCT source_city_code)::INTEGER AS row_count
  FROM (
    SELECT source_city_code FROM staging.stg_gbfs_station
    UNION ALL
    SELECT source_city_code FROM staging.stg_weather
    UNION ALL
    SELECT source_city_code FROM staging.stg_divvy_trips
    UNION ALL
    SELECT source_city_code FROM staging.stg_citibike_trips
  ) c
  WHERE source_city_code IN ('CHI', 'NYC')
),
date_candidates AS (
  SELECT started_at::DATE AS calendar_date FROM staging.stg_divvy_trips WHERE started_at IS NOT NULL
  UNION ALL
  SELECT ended_at::DATE FROM staging.stg_divvy_trips WHERE ended_at IS NOT NULL
  UNION ALL
  SELECT started_at::DATE FROM staging.stg_citibike_trips WHERE started_at IS NOT NULL
  UNION ALL
  SELECT ended_at::DATE FROM staging.stg_citibike_trips WHERE ended_at IS NOT NULL
  UNION ALL
  SELECT observation_ts::DATE FROM staging.stg_weather WHERE observation_ts IS NOT NULL
),
calendar_rows AS (
  SELECT
    CASE
      WHEN COUNT(calendar_date) = 0 THEN 0
      ELSE (MAX(calendar_date) - MIN(calendar_date) + 1)::INTEGER
    END AS row_count
  FROM date_candidates
),
station_rows AS (
  SELECT COUNT(*)::INTEGER AS row_count
  FROM staging.stg_gbfs_station
  WHERE short_name IS NOT NULL
),
weather_rows AS (
  SELECT COUNT(*)::INTEGER AS row_count
  FROM (
    SELECT source_city_code, date_trunc('hour', observation_ts) AS observation_hour
    FROM staging.stg_weather
    WHERE observation_ts IS NOT NULL
    GROUP BY source_city_code, date_trunc('hour', observation_ts)
  ) w
),
trip_rows AS (
  SELECT COUNT(DISTINCT (source_city_code, ride_id))::INTEGER AS row_count
  FROM (
    SELECT source_city_code, ride_id
    FROM staging.stg_divvy_trips
    WHERE ride_id IS NOT NULL AND started_at IS NOT NULL
    UNION ALL
    SELECT source_city_code, ride_id
    FROM staging.stg_citibike_trips
    WHERE ride_id IS NOT NULL AND started_at IS NOT NULL
  ) t
)
SELECT (city_rows.row_count + calendar_rows.row_count + station_rows.row_count + weather_rows.row_count + trip_rows.row_count)::INTEGER
FROM city_rows, calendar_rows, station_rows, weather_rows, trip_rows;
")"
staging_to_nds_success_rows="${staging_to_nds_success_rows:-0}"

psql_control -v started_at="$ETL_STAGINGDB_TO_NDS_STARTED_AT" -v row_count="$staging_to_nds_success_rows" <<'SQL'
INSERT INTO control.etl_job_log (
    job_name,
    source_name,
    started_at,
    finished_at,
    status,
    total_rows_count,
    success_rows_count,
    failed_rows_count
)
VALUES (
    'etl_stagingdb_to_nds',
    'stagingdb_to_nds',
    :'started_at'::timestamp,
    CURRENT_TIMESTAMP,
    'SUCCESS',
    :row_count,
    :row_count,
    0
);
SQL

psql_nds <<'SQL'
TRUNCATE TABLE import.stg_trip;
SQL

docker exec -i "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging <<'SQL'
TRUNCATE TABLE
  staging.raw_divvy_trips,
  staging.raw_citibike_trips,
  staging.raw_noaa_weather,
  staging.raw_gbfs_station,
  staging.stg_divvy_trips,
  staging.stg_citibike_trips,
  staging.stg_weather,
  staging.stg_gbfs_station;
SQL

docker exec "$NDS_CONTAINER" psql -U postgres -d dw_nds -Atc "
SELECT 'nds_city', COUNT(*) FROM nds.city
UNION ALL SELECT 'nds_calendar_day', COUNT(*) FROM nds.calendar_day
UNION ALL SELECT 'nds_station', COUNT(*) FROM nds.station
UNION ALL SELECT 'nds_weather', COUNT(*) FROM nds.weather
UNION ALL SELECT 'nds_trip', COUNT(*) FROM nds.trip;
"

docker exec "$STG_CONTAINER" psql -U postgres -d dw_staging -Atc "
SELECT 'staging_raw_stg_remaining', SUM(row_count)
FROM (
  SELECT COUNT(*) AS row_count FROM staging.raw_divvy_trips
  UNION ALL SELECT COUNT(*) FROM staging.raw_citibike_trips
  UNION ALL SELECT COUNT(*) FROM staging.raw_noaa_weather
  UNION ALL SELECT COUNT(*) FROM staging.raw_gbfs_station
  UNION ALL SELECT COUNT(*) FROM staging.stg_divvy_trips
  UNION ALL SELECT COUNT(*) FROM staging.stg_citibike_trips
  UNION ALL SELECT COUNT(*) FROM staging.stg_weather
  UNION ALL SELECT COUNT(*) FROM staging.stg_gbfs_station
) c;
"
