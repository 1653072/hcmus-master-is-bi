#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPE_DIR="$ROOT/D_pipelines/01_Load_Source_Files_To_Staging"
WORKFLOW="$ROOT/E_workflows/01_load_source_files_to_staging.hwf"
README="$ROOT/README.md"
STAGING_SQL="$ROOT/B_databases/B1_dw_stg_postgresql/02_staging_schema.sql"

required_pipelines=(
  "01_load_divvy_trips_to_staging.hpl"
  "02_load_citibike_trips_to_staging.hpl"
  "03_load_noaa_weather_to_staging.hpl"
  "04_load_gbfs_station_to_staging.hpl"
  "05_audit_staging_load_counts.hpl"
)

for pipeline in "${required_pipelines[@]}"; do
  path="$PIPE_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
done

test -f "$WORKFLOW"
xmllint --noout "$WORKFLOW" >/dev/null

grep -q "Source Files → StagingDB" "$README"
grep -q "A_datasets/.*operational landing layer" "$README"
grep -q "không.*batch_id" "$README"

grep -q "<type>InsertUpdate</type>" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "<type>InsertUpdate</type>" "$PIPE_DIR/02_load_citibike_trips_to_staging.hpl"
grep -q "<type>InsertUpdate</type>" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "<type>InsertUpdate</type>" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"
grep -q "etl_extraction_control" "$PIPE_DIR/05_audit_staging_load_counts.hpl"
grep -q "etl_job_log" "$PIPE_DIR/05_audit_staging_load_counts.hpl"
grep -q "<name>source_city_code</name>" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "<name>ride_id</name>" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "<name>source_city_code</name>" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "<name>observation_ts</name>" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "<name>source_city_code</name>" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"
grep -q "<name>short_name</name>" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"

grep -q "DIVVY_TRIPS_DIR" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "CITIBIKE_TRIPS_DIR" "$PIPE_DIR/02_load_citibike_trips_to_staging.hpl"
grep -q "\\[0-9\\]{6}.*\\\\.csv" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "\\[0-9\\]{6}.*\\\\.csv" "$PIPE_DIR/02_load_citibike_trips_to_staging.hpl"
grep -q "NOAA_LCD_CHICAGO" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "NOAA_LCD_NYC" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "GBFS_STATION_DIR" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"
grep -q "05_audit_staging_load_counts.hpl" "$WORKFLOW"

grep -q "REPORT_TYPE.*FM-15" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "6602.05" "$README"
grep -q "CHI02042" "$README"

if grep -q "CREATE INDEX idx_stg_" "$STAGING_SQL"; then
  echo "Unexpected secondary staging indexes remain in $STAGING_SQL" >&2
  exit 1
fi
