#!/usr/bin/env bash
set -euo pipefail

STG_CONTAINER="${STG_CONTAINER:-hcmus-bi-official-db-dw-stg-postgres}"
NDS_CONTAINER="${NDS_CONTAINER:-hcmus-bi-official-db-dw-nds-postgres}"

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

assert_positive "stg_divvy_trips" "$(stg_query "SELECT COUNT(*) FROM staging.stg_divvy_trips;")"
assert_positive "stg_citibike_trips" "$(stg_query "SELECT COUNT(*) FROM staging.stg_citibike_trips;")"
assert_positive "stg_weather" "$(stg_query "SELECT COUNT(*) FROM staging.stg_weather;")"
assert_positive "stg_gbfs_station" "$(stg_query "SELECT COUNT(*) FROM staging.stg_gbfs_station;")"
assert_positive "dq_rule_result_details" "$(control_query "SELECT COUNT(*) FROM control.etl_dq_rule_result_details;")"
assert_positive "dq_rule_result" "$(control_query "SELECT COUNT(*) FROM control.etl_dq_rule_result_analysis;")"
assert_positive "nds_station" "$(nds_query "SELECT COUNT(*) FROM nds.station;")"
assert_positive "nds_weather" "$(nds_query "SELECT COUNT(*) FROM nds.weather;")"
assert_positive "nds_trip" "$(nds_query "SELECT COUNT(*) FROM nds.trip;")"

assert_zero "invalid nds.weather.weather_category" "$(nds_query "SELECT COUNT(*) FROM nds.weather WHERE weather_category IS NULL OR weather_category NOT IN ('Clear','Rain','Snow','Fog');")"
assert_zero "invalid nds.trip.rideable_type" "$(nds_query "SELECT COUNT(*) FROM nds.trip WHERE rideable_type IS NULL OR rideable_type NOT IN ('classic_bike','electric_bike');")"
assert_zero "invalid nds.trip.member_casual" "$(nds_query "SELECT COUNT(*) FROM nds.trip WHERE member_casual IS NULL OR member_casual NOT IN ('member','casual');")"
assert_zero "invalid nds.weather.report_type" "$(nds_query "SELECT COUNT(*) FROM nds.weather WHERE report_type IS NULL OR report_type NOT IN ('FM-15','FM-16','FM-12');")"

nds_trip_count="$(nds_query "SELECT COUNT(*) FROM nds.trip;")"
nds_trip_distinct_count="$(nds_query "SELECT COUNT(DISTINCT (city_sk, ride_id)) FROM nds.trip;")"
assert_equals "nds.trip distinct city_sk/ride_id" "$nds_trip_distinct_count" "$nds_trip_count"

active_staging_sessions="$(stg_query "
SELECT COUNT(*)
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND datname = current_database()
  AND state IN ('active', 'idle in transaction')
  AND query NOT ILIKE '%pg_stat_activity%';
")"

if [ "${active_staging_sessions:-0}" -eq 0 ]; then
  staging_trip_distinct_count="$(stg_query "
SELECT COUNT(DISTINCT (source_city_code, ride_id))
FROM (
  SELECT source_city_code, ride_id
  FROM staging.stg_divvy_trips
  WHERE ride_id IS NOT NULL AND started_at IS NOT NULL
  UNION ALL
  SELECT source_city_code, ride_id
  FROM staging.stg_citibike_trips
  WHERE ride_id IS NOT NULL AND started_at IS NOT NULL
) s;
")"
  assert_equals "nds.trip vs staging distinct valid trip keys" "$nds_trip_count" "$staging_trip_distinct_count"
else
  echo "Skipping staging-vs-NDS trip equality: $active_staging_sessions staging session(s) are active or idle in transaction." >&2
fi
