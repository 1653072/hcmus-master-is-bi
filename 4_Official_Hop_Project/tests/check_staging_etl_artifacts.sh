#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPE_DIR="$ROOT/D_pipelines/01_ETL_Source_To_StagingDB"
WORKFLOW="$ROOT/E_workflows/01_etl_source_to_stagingdb.hwf"
README="$ROOT/README.md"
STAGING_SQL="$ROOT/B_databases/B1_dw_stg_postgresql/02_staging_schema.sql"
DPIPE_ROOT="$ROOT/D_pipelines"
DDS_DIR="$ROOT/D_pipelines/03_ETL_NDS_To_DDS"

expected_pipeline_dirs=$'01_ETL_Source_To_StagingDB\n02_ETL_StagingDB_To_NDS\n03_ETL_NDS_To_DDS'
actual_pipeline_dirs="$(
  find "$DPIPE_ROOT" -mindepth 1 -maxdepth 1 -type d | sed 's|.*/||' | sort
)"
test "$actual_pipeline_dirs" = "$expected_pipeline_dirs"

test -d "$DDS_DIR"
for pipeline in \
  "D1_Load_Dim_City.hpl" \
  "D2_Load_Dim_Station.hpl" \
  "D3_Aggregate_Fact_StationHourBalance.hpl"; do
  path="$DDS_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
done

required_pipelines=(
  "00_start_etl_source_to_staging.hpl"
  "01_load_divvy_trips_to_staging.hpl"
  "01_validate_divvy_raw_to_staging.hpl"
  "02_load_citibike_trips_to_staging.hpl"
  "02_validate_citibike_raw_to_staging.hpl"
  "03_load_noaa_weather_to_staging.hpl"
  "03_validate_noaa_raw_to_staging.hpl"
  "04_load_gbfs_station_to_staging.hpl"
  "04_validate_gbfs_raw_to_staging.hpl"
  "05_audit_dq_rule_results.hpl"
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

grep -q "<type>SetVariable</type>" "$PIPE_DIR/00_start_etl_source_to_staging.hpl"
grep -q "ETL_STARTED_AT" "$PIPE_DIR/00_start_etl_source_to_staging.hpl"
grep -q "<type>ExecSql</type>" "$PIPE_DIR/00_start_etl_source_to_staging.hpl"
grep -q "DELETE FROM control.etl_dq_rule_result_analysis" "$PIPE_DIR/00_start_etl_source_to_staging.hpl"
grep -q "DELETE FROM control.etl_dq_rule_result_details" "$PIPE_DIR/00_start_etl_source_to_staging.hpl"

grep -q "<type>TableOutput</type>" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "<table>raw_divvy_trips</table>" "$PIPE_DIR/01_load_divvy_trips_to_staging.hpl"
grep -q "<type>TableOutput</type>" "$PIPE_DIR/02_load_citibike_trips_to_staging.hpl"
grep -q "<table>raw_citibike_trips</table>" "$PIPE_DIR/02_load_citibike_trips_to_staging.hpl"
grep -q "<type>TableOutput</type>" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "<table>raw_noaa_weather</table>" "$PIPE_DIR/03_load_noaa_weather_to_staging.hpl"
grep -q "<type>TableOutput</type>" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"
grep -q "<table>raw_gbfs_station</table>" "$PIPE_DIR/04_load_gbfs_station_to_staging.hpl"

for pipeline in \
  "01_validate_divvy_raw_to_staging.hpl" \
  "03_validate_noaa_raw_to_staging.hpl" \
  "04_validate_gbfs_raw_to_staging.hpl"; do
  grep -q "<type>InsertUpdate</type>" "$PIPE_DIR/$pipeline"
  grep -q "etl_dq_rule_result_details" "$PIPE_DIR/$pipeline"
  grep -q "etl_dq_rule_result_analysis" "$PIPE_DIR/$pipeline"
done

grep -q "<type>ExecSql</type>" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "INSERT INTO staging.stg_citibike_trips" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "ON CONFLICT (source_city_code, ride_id)" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "IS DISTINCT FROM" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "CITIBIKE_VALIDATE_MONTH" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "CITIBIKE_RESULT_LOAD_RUN_ID" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "etl_dq_rule_result_details" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "etl_dq_rule_result_analysis" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
if grep -q "<name>Cast Citi Bike clean rows</name>" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl" || \
   grep -q "<name>Upsert staging.stg_citibike_trips</name>" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"; then
  echo "Citi Bike accepted branch must remain set-based, not row-by-row ScriptValueMod/InsertUpdate" >&2
  exit 1
fi

grep -q "<table>stg_divvy_trips</table>" "$PIPE_DIR/01_validate_divvy_raw_to_staging.hpl"
grep -q "staging.stg_citibike_trips" "$PIPE_DIR/02_validate_citibike_raw_to_staging.hpl"
grep -q "<table>stg_weather</table>" "$PIPE_DIR/03_validate_noaa_raw_to_staging.hpl"
grep -q "<table>stg_gbfs_station</table>" "$PIPE_DIR/04_validate_gbfs_raw_to_staging.hpl"
grep -q "etl_dq_rule_result_analysis" "$PIPE_DIR/05_audit_dq_rule_results.hpl"
grep -q "etl_job_log" "$PIPE_DIR/05_audit_dq_rule_results.hpl"
grep -q "etl_source_to_stagingdb_dq_validation" "$PIPE_DIR/05_audit_dq_rule_results.hpl"
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
grep -q "00_start_etl_source_to_staging.hpl" "$WORKFLOW"
grep -q "01_validate_divvy_raw_to_staging.hpl" "$WORKFLOW"
grep -q "02_validate_citibike_raw_to_staging.hpl" "$WORKFLOW"
grep -q "03_validate_noaa_raw_to_staging.hpl" "$WORKFLOW"
grep -q "04_validate_gbfs_raw_to_staging.hpl" "$WORKFLOW"
grep -q "05_audit_dq_rule_results.hpl" "$WORKFLOW"
grep -q "05_audit_staging_load_counts.hpl" "$WORKFLOW"

grep -q "report_type.*FM-15" "$PIPE_DIR/03_validate_noaa_raw_to_staging.hpl"
grep -q "6602.05" "$README"
grep -q "CHI02042" "$README"

if grep -q "CREATE INDEX idx_stg_" "$STAGING_SQL"; then
  echo "Unexpected secondary staging indexes remain in $STAGING_SQL" >&2
  exit 1
fi
