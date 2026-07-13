#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPE_DIR="$ROOT/D_pipelines/02_ETL_StagingDB_To_NDS"
WORKFLOW="$ROOT/E_workflows/02_etl_stagingdb_to_nds.hwf"

pipelines=(
  00_start_etl_stagingdb_to_nds.hpl
  00_check_staging_dq_before_nds.hpl
  01_load_city_calendar_to_nds.hpl
  02_load_gbfs_station_to_nds.hpl
  03_load_weather_to_nds.hpl
  04_load_trips_to_nds.hpl
  05_audit_stagingdb_to_nds_job_log.hpl
  06_cleanup_staging_after_nds.hpl
)

xmllint --noout "$WORKFLOW"
for pipeline in "${pipelines[@]}"; do
  test -f "$PIPE_DIR/$pipeline"
  xmllint --noout "$PIPE_DIR/$pipeline"
  grep -q "<name>${pipeline%.hpl}</name>" "$PIPE_DIR/$pipeline"
  grep -q "$pipeline" "$WORKFLOW"
done

pipeline_count="$(xmllint --xpath "count(/workflow/actions/action[type='PIPELINE'])" "$WORKFLOW")"
safe_count="$(xmllint --xpath "count(/workflow/actions/action[type='PIPELINE' and wait_until_finished='Y' and parameters/pass_all_parameters='Y' and parallel='N'])" "$WORKFLOW")"
test "$pipeline_count" = "$safe_count"

trip="$PIPE_DIR/04_load_trips_to_nds.hpl"
grep -q 'stg_divvy_trips' "$trip"
grep -q 'stg_citibike_trips' "$trip"
grep -q 'DISTINCT ON (source_city_code, ride_id)' "$trip"
grep -q '<type>DBLookup</type>' "$trip"
grep -q '<name>Lookup city_sk</name>' "$trip"
grep -q '<type>FilterRows</type>' "$trip"
grep -q '<function>IS NOT NULL</function>' "$trip"
grep -q '<name>Lookup start_station_sk</name>' "$trip"
grep -q '<name>Lookup end_station_sk</name>' "$trip"
grep -q '<name>is_current</name><field>is_current</field>' "$trip"
grep -q '<type>InsertUpdate</type>' "$trip"
grep -q '<name>Upsert nds.trip</name>' "$trip"
grep -q '<schema>nds</schema><table>trip</table>' "$trip"
grep -q 'duration_minutes' "$trip"

if grep -R -Eq 'import\.stg_trip|03_prepare_trip_buffer|03_merge_trip_buffer_to_nds|05_cleanup_nds_trip_buffer' \
  "$ROOT/B_databases" "$PIPE_DIR" "$WORKFLOW"; then
  echo 'Obsolete trip-buffer artifact remains' >&2
  exit 1
fi

grep -q '<type>GetVariable</type>' "$PIPE_DIR/05_audit_stagingdb_to_nds_job_log.hpl"
grep -q '<type>ExecSql</type>' "$PIPE_DIR/06_cleanup_staging_after_nds.hpl"
grep -q "ELSE 'Clear'" "$PIPE_DIR/03_load_weather_to_nds.hpl"
grep -q "THEN 'Rain'" "$PIPE_DIR/03_load_weather_to_nds.hpl"
grep -q "THEN 'Snow'" "$PIPE_DIR/03_load_weather_to_nds.hpl"
grep -q "THEN 'Fog'" "$PIPE_DIR/03_load_weather_to_nds.hpl"

echo 'NDS ETL artifacts OK'
