#!/usr/bin/env bash
set -euo pipefail

STG_CONTAINER="${STG_CONTAINER:-hcmus-bi-official-db-dw-stg-postgres}"
NDS_CONTAINER="${NDS_CONTAINER:-hcmus-bi-official-db-dw-nds-postgres}"

psql_nds() {
  docker exec -i "$NDS_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_nds "$@"
}

copy_from_stg_to_nds() {
  local select_sql="$1"
  local copy_sql="$2"
  docker exec "$STG_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_staging -c "COPY (${select_sql}) TO STDOUT WITH CSV" \
    | docker exec -i "$NDS_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d dw_nds -c "$copy_sql"
}

psql_nds <<'SQL'
CREATE SCHEMA IF NOT EXISTS import;

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

CREATE TABLE IF NOT EXISTS import.stg_trip (
    source_city_code TEXT,
    ride_id TEXT,
    rideable_type TEXT,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    start_station_id TEXT,
    end_station_id TEXT,
    start_lat NUMERIC(12,8),
    start_lng NUMERIC(12,8),
    end_lat NUMERIC(12,8),
    end_lng NUMERIC(12,8),
    member_casual TEXT,
    trip_month CHAR(6)
);

TRUNCATE TABLE import.stg_gbfs_station, import.stg_weather, import.stg_trip;
SQL

copy_from_stg_to_nds \
  "SELECT source_city_code, short_name, station_name, latitude, longitude, capacity, station_status FROM staging.stg_gbfs_station" \
  "COPY import.stg_gbfs_station FROM STDIN WITH CSV"

copy_from_stg_to_nds \
  "SELECT source_city_code, observation_ts, report_type, hourly_dry_bulb_temperature, hourly_precipitation, hourly_wind_speed, hourly_present_weather_type FROM staging.stg_weather" \
  "COPY import.stg_weather FROM STDIN WITH CSV"

copy_from_stg_to_nds \
  "SELECT source_city_code, ride_id, rideable_type, started_at, ended_at, start_station_id, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual, trip_month FROM staging.stg_divvy_trips UNION ALL SELECT source_city_code, ride_id, rideable_type, started_at, ended_at, start_station_id, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual, trip_month FROM staging.stg_citibike_trips" \
  "COPY import.stg_trip FROM STDIN WITH CSV"

psql_nds <<'SQL'
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
    loaded_at = CURRENT_TIMESTAMP;
SQL

docker exec "$NDS_CONTAINER" psql -U postgres -d dw_nds -Atc "
SELECT 'nds_station', COUNT(*) FROM nds.station
UNION ALL SELECT 'nds_weather', COUNT(*) FROM nds.weather
UNION ALL SELECT 'nds_trip', COUNT(*) FROM nds.trip;
"
