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

assert_positive "raw_divvy_trips" "$(stg_query "SELECT COUNT(*) FROM staging.raw_divvy_trips;")"
assert_positive "raw_citibike_trips" "$(stg_query "SELECT COUNT(*) FROM staging.raw_citibike_trips;")"
assert_positive "raw_noaa_weather" "$(stg_query "SELECT COUNT(*) FROM staging.raw_noaa_weather;")"
assert_positive "raw_gbfs_station" "$(stg_query "SELECT COUNT(*) FROM staging.raw_gbfs_station;")"
assert_positive "dq_warning_row" "$(stg_query "SELECT COUNT(*) FROM staging.dq_warning_row;")"
assert_positive "dq_rule_result" "$(control_query "SELECT COUNT(*) FROM control.etl_dq_rule_result;")"
assert_positive "nds_station" "$(nds_query "SELECT COUNT(*) FROM nds.station;")"
assert_positive "nds_weather" "$(nds_query "SELECT COUNT(*) FROM nds.weather;")"
assert_positive "nds_trip" "$(nds_query "SELECT COUNT(*) FROM nds.trip;")"
