#!/usr/bin/env bash
set -euo pipefail

STG_CONTAINER="${STG_CONTAINER:-hcmus-bi-official-db-dw-stg-postgres}"
NDS_CONTAINER="${NDS_CONTAINER:-hcmus-bi-official-db-dw-nds-postgres}"
NDS_EXPECT_TRIP_LOADED_AT_MAX="${NDS_EXPECT_TRIP_LOADED_AT_MAX:-}"

stg_query() {
  docker exec "$STG_CONTAINER" psql -U postgres -d dw_staging -Atc "$1"
}

control_query() {
  docker exec "$STG_CONTAINER" psql -U postgres -d dw_control -Atc "$1"
}

nds_query() {
  docker exec "$NDS_CONTAINER" psql -U postgres -d dw_nds -Atc "$1"
}

assert_positive() {
  local name="$1"
  local value="$2"
  if [ "${value:-0}" -le 0 ]; then
    echo "$name expected > 0, got $value" >&2
    exit 1
  fi
}

assert_zero() {
  local name="$1"
  local value="$2"
  if [ "${value:-0}" -ne 0 ]; then
    echo "$name expected 0, got $value" >&2
    exit 1
  fi
}

assert_equals() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" != "$expected" ]; then
    echo "$name expected $expected, got $actual" >&2
    exit 1
  fi
}

assert_positive "nds_city" "$(nds_query "SELECT COUNT(*) FROM nds.city;")"
assert_positive "nds_calendar_day" "$(nds_query "SELECT COUNT(*) FROM nds.calendar_day;")"
assert_positive "nds_station" "$(nds_query "SELECT COUNT(*) FROM nds.station;")"
assert_positive "nds_weather" "$(nds_query "SELECT COUNT(*) FROM nds.weather;")"
assert_positive "nds_trip" "$(nds_query "SELECT COUNT(*) FROM nds.trip;")"

assert_zero "invalid nds.city.city_code" "$(nds_query "SELECT COUNT(*) FROM nds.city WHERE city_code NOT IN ('CHI','NYC') OR city_name IS NULL OR timezone IS NULL;")"
assert_zero "invalid nds.calendar_day.day_of_week" "$(nds_query "SELECT COUNT(*) FROM nds.calendar_day WHERE day_of_week NOT BETWEEN 1 AND 7;")"
assert_zero "invalid nds.calendar_day.month" "$(nds_query "SELECT COUNT(*) FROM nds.calendar_day WHERE month NOT BETWEEN 1 AND 12;")"
assert_zero "invalid nds.calendar_day.season" "$(nds_query "SELECT COUNT(*) FROM nds.calendar_day WHERE season NOT IN ('winter','spring','summer','fall');")"
assert_zero "invalid nds.weather.weather_category" "$(nds_query "SELECT COUNT(*) FROM nds.weather WHERE weather_category IS NULL OR weather_category NOT IN ('Clear','Rain','Snow','Fog');")"
assert_zero "invalid nds.trip.rideable_type" "$(nds_query "SELECT COUNT(*) FROM nds.trip WHERE rideable_type IS NULL OR rideable_type NOT IN ('classic_bike','electric_bike');")"
assert_zero "invalid nds.trip.member_casual" "$(nds_query "SELECT COUNT(*) FROM nds.trip WHERE member_casual IS NULL OR member_casual NOT IN ('member','casual');")"
assert_zero "invalid nds.weather.report_type" "$(nds_query "SELECT COUNT(*) FROM nds.weather WHERE report_type IS NULL OR report_type NOT IN ('FM-15','FM-16','FM-12');")"

assert_zero "obsolete import.stg_trip still exists" "$(nds_query "SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'import' AND c.relname = 'stg_trip';")"

nds_trip_count="$(nds_query "SELECT COUNT(*) FROM nds.trip;")"
nds_trip_distinct_count="$(nds_query "SELECT COUNT(DISTINCT (city_sk, ride_id)) FROM nds.trip;")"
assert_equals "nds.trip distinct city_sk/ride_id" "$nds_trip_distinct_count" "$nds_trip_count"

assert_zero "nds.trip station_sk mapped to another city" "$(nds_query "
SELECT COUNT(*)
FROM (
  SELECT t.trip_sk
  FROM nds.trip t
  JOIN nds.station s ON s.station_sk = t.start_station_sk
  WHERE s.city_sk <> t.city_sk
  UNION ALL
  SELECT t.trip_sk
  FROM nds.trip t
  JOIN nds.station s ON s.station_sk = t.end_station_sk
  WHERE s.city_sk <> t.city_sk
) bad;
")"

assert_zero "invalid nds.trip.duration_minutes" "$(nds_query "
SELECT COUNT(*)
FROM nds.trip
WHERE (
    ended_at IS NOT NULL
    AND ended_at >= started_at
    AND duration_minutes IS DISTINCT FROM ROUND((EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0)::NUMERIC, 2)
  )
  OR (
    (ended_at IS NULL OR ended_at < started_at)
    AND duration_minutes IS NOT NULL
  );
")"

assert_zero "trip start station mapped to another city" "$(nds_query "
SELECT COUNT(*)
FROM nds.trip t
JOIN nds.station s ON s.station_sk = t.start_station_sk
WHERE s.city_sk <> t.city_sk;
")"
assert_zero "trip end station mapped to another city" "$(nds_query "
SELECT COUNT(*)
FROM nds.trip t
JOIN nds.station s ON s.station_sk = t.end_station_sk
WHERE s.city_sk <> t.city_sk;
")"
assert_zero "invalid nds.trip.duration_minutes" "$(nds_query "
SELECT COUNT(*)
FROM nds.trip
WHERE duration_minutes IS DISTINCT FROM
  CASE
    WHEN ended_at IS NOT NULL AND ended_at >= started_at
    THEN ROUND((EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0)::NUMERIC, 2)
    ELSE NULL
  END;
")"

if [ -n "$NDS_EXPECT_TRIP_LOADED_AT_MAX" ]; then
  assert_equals "nds.trip loaded_at max after no-op rerun" "$(nds_query "
SELECT COALESCE(TO_CHAR(MAX(loaded_at), 'YYYY-MM-DD HH24:MI:SS.US'), '')
FROM nds.trip;
")" "$NDS_EXPECT_TRIP_LOADED_AT_MAX"
fi

assert_zero "source-to-staging control rows not successful" "$(control_query "
SELECT COUNT(*)
FROM control.etl_extraction_control
WHERE source_name IN ('divvy_trips', 'citibike_trips', 'noaa_lcd', 'gbfs_station')
  AND COALESCE(last_run_status, 'FAILED') <> 'SUCCESS';
")"

assert_positive "etl_stagingdb_to_nds job log" "$(control_query "
SELECT COUNT(*)
FROM (
  SELECT *
  FROM control.etl_job_log
  WHERE job_name = 'etl_stagingdb_to_nds'
    AND source_name = 'stagingdb_to_nds'
  ORDER BY finished_at DESC, log_id DESC
  LIMIT 1
) latest
WHERE job_name = 'etl_stagingdb_to_nds'
  AND source_name = 'stagingdb_to_nds'
  AND status = 'SUCCESS'
  AND started_at IS NOT NULL
  AND finished_at IS NOT NULL
  AND total_rows_count >= 0
  AND success_rows_count = total_rows_count
  AND failed_rows_count = 0;
")"

assert_zero "post-NDS raw/stg staging rows" "$(stg_query "
SELECT COALESCE(SUM(row_count), 0)
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
")"

assert_zero "staging tables without Hop TRUNCATE permission" "$(stg_query "
SELECT COUNT(*)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'staging'
  AND c.relname IN (
    'raw_divvy_trips', 'raw_citibike_trips', 'raw_noaa_weather', 'raw_gbfs_station',
    'stg_divvy_trips', 'stg_citibike_trips', 'stg_weather', 'stg_gbfs_station'
  )
  AND NOT has_table_privilege('hop_staging_user', c.oid, 'TRUNCATE');
")"
