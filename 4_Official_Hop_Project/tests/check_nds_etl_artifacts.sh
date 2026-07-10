#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPE_DIR="$ROOT/D_pipelines/02_ETL_StagingDB_To_NDS"
WORKFLOW="$ROOT/E_workflows/02_etl_stagingdb_to_nds.hwf"
DDS_WORKFLOW="$ROOT/E_workflows/03_etl_nds_to_dds.hwf"
RUNTIME_SCRIPT="$ROOT/scripts/run_staging_to_nds.sh"

assert_no_shell_blackbox() {
  local path="$1"
  if grep -q '<type>SHELL</type>' "$path" || grep -q 'scripts/run_' "$path"; then
    echo "Unexpected shell blackbox references remain in $path" >&2
    exit 1
  fi
}

assert_has_real_transform() {
  local path="$1"
  if ! grep -Eq '<type>(TableInput|TableOutput|InsertUpdate|DBLookup|FilterRows|SelectValues|Constant|RowGenerator|ScriptValueMod|TextFileInput2|JsonInput|SetVariable|GetVariable|ExecSql)</type>' "$path"; then
    echo "Expected a real transform in $path" >&2
    exit 1
  fi
}

assert_workflow_order() {
  local previous=0
  local label line
  for label in "$@"; do
    line="$(grep -n "$label" "$WORKFLOW" | head -1 | cut -d: -f1 || true)"
    if [ -z "$line" ]; then
      echo "Expected workflow label not found: $label" >&2
      exit 1
    fi
    if [ "$line" -le "$previous" ]; then
      echo "Workflow label out of order: $label" >&2
      exit 1
    fi
    previous="$line"
  done
}

test -d "$PIPE_DIR"
test -f "$WORKFLOW"
test -f "$DDS_WORKFLOW"
test -f "$RUNTIME_SCRIPT"
test -x "$RUNTIME_SCRIPT"
xmllint --noout "$WORKFLOW" >/dev/null
xmllint --noout "$DDS_WORKFLOW" >/dev/null
assert_no_shell_blackbox "$WORKFLOW"
assert_no_shell_blackbox "$DDS_WORKFLOW"
xmllint --noout "$DDS_WORKFLOW" >/dev/null

for pipeline in \
  "00_start_etl_stagingdb_to_nds.hpl" \
  "00_check_staging_dq_before_nds.hpl" \
  "01_load_city_calendar_to_nds.hpl" \
  "01_load_gbfs_station_to_nds.hpl" \
  "02_load_weather_to_nds.hpl" \
  "03_prepare_trip_buffer.hpl" \
  "03_load_trips_to_nds.hpl" \
  "03_merge_trip_buffer_to_nds.hpl" \
  "04_audit_stagingdb_to_nds_job_log.hpl" \
  "05_cleanup_nds_trip_buffer.hpl" \
  "05_cleanup_staging_after_nds.hpl"; do
  path="$PIPE_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
  assert_has_real_transform "$path"
done

assert_workflow_order \
  "00_start_etl_stagingdb_to_nds.hpl" \
  "Check staging/NDS/control DB" \
  "00_check_staging_dq_before_nds.hpl" \
  "01_load_city_calendar_to_nds.hpl" \
  "01_load_gbfs_station_to_nds.hpl" \
  "02_load_weather_to_nds.hpl" \
  "03_prepare_trip_buffer.hpl" \
  "03_load_trips_to_nds.hpl" \
  "03_merge_trip_buffer_to_nds.hpl" \
  "04_audit_stagingdb_to_nds_job_log.hpl" \
  "05_cleanup_nds_trip_buffer.hpl" \
  "05_cleanup_staging_after_nds.hpl" \
  "Success"

pipeline_action_count="$(xmllint --xpath "count(/workflow/actions/action[type='PIPELINE'])" "$WORKFLOW")"
safe_pipeline_action_count="$(xmllint --xpath "count(/workflow/actions/action[type='PIPELINE' and wait_until_finished='Y' and parameters/pass_all_parameters='Y' and parallel='N'])" "$WORKFLOW")"
if [ "$pipeline_action_count" != "$safe_pipeline_action_count" ]; then
  echo "Every dependent workflow pipeline must wait, pass all parameters, and run non-parallel" >&2
  exit 1
fi

grep -q "<type>SetVariable</type>" "$PIPE_DIR/00_start_etl_stagingdb_to_nds.hpl"
grep -q "ETL_STAGINGDB_TO_NDS_STARTED_AT" "$PIPE_DIR/00_start_etl_stagingdb_to_nds.hpl"
grep -q "<type>ExecSql</type>" "$PIPE_DIR/00_check_staging_dq_before_nds.hpl"
grep -q "etl_extraction_control" "$PIPE_DIR/00_check_staging_dq_before_nds.hpl"
grep -q "last_run_status" "$PIPE_DIR/00_check_staging_dq_before_nds.hpl"
grep -q "<single_statement>Y</single_statement>" "$PIPE_DIR/00_check_staging_dq_before_nds.hpl"
grep -q "nds.city" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "nds.calendar_day" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "stg_divvy_trips" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "stg_citibike_trips" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "stg_weather" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "generate_series" "$PIPE_DIR/01_load_city_calendar_to_nds.hpl"
grep -q "nds.city" "$RUNTIME_SCRIPT"
grep -q "nds.calendar_day" "$RUNTIME_SCRIPT"
grep -q "stg_gbfs_station" "$PIPE_DIR/01_load_gbfs_station_to_nds.hpl"
grep -q "nds.station" "$PIPE_DIR/01_load_gbfs_station_to_nds.hpl"
grep -q "stg_weather" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "weather_category" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "ELSE 'Clear'" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "THEN 'Rain'" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "THEN 'Snow'" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "THEN 'Fog'" "$PIPE_DIR/02_load_weather_to_nds.hpl"
legacy_wet="we""t"
legacy_freezing="free""zing"
legacy_windy="win""dy"
legacy_lower_clear="cle""ar"
if grep -Eq "THEN '($legacy_wet|$legacy_freezing|$legacy_windy|$legacy_lower_clear)'" "$PIPE_DIR/02_load_weather_to_nds.hpl" "$RUNTIME_SCRIPT"; then
  echo "Legacy weather_category values remain; expected Clear/Rain/Snow/Fog" >&2
  exit 1
fi
deprecated_lookup_type='<type>Database''Lookup</type>'
if grep -R -q "$deprecated_lookup_type" "$PIPE_DIR"; then
  echo "Unexpected deprecated DatabaseLookup transform type; expected DBLookup" >&2
  exit 1
fi
grep -q "stg_divvy_trips" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "stg_citibike_trips" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "<type>TableOutput</type>" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "<use_batch>Y</use_batch>" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "<commit>10000</commit>" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "<schema>import</schema>" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "<table>stg_trip</table>" "$PIPE_DIR/03_load_trips_to_nds.hpl"
if grep -Eq "<type>(DBLookup|InsertUpdate|ScriptValueMod)</type>" "$PIPE_DIR/03_load_trips_to_nds.hpl"; then
  echo "Trip load pipeline must bulk-copy to import.stg_trip without row-by-row lookup/upsert transforms" >&2
  exit 1
fi
grep -q "<type>ExecSql</type>" "$PIPE_DIR/03_prepare_trip_buffer.hpl"
grep -q "TRUNCATE TABLE import.stg_trip" "$PIPE_DIR/03_prepare_trip_buffer.hpl"
grep -q "<type>ExecSql</type>" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "Duplicate trip keys in import.stg_trip" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "source_city_code values that do not map to nds.city" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "Ambiguous current station mapping" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "LEFT JOIN nds.station ss" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "LEFT JOIN nds.station es" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "ss.city_sk = c.city_sk" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "es.city_sk = c.city_sk" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "ON CONFLICT (city_sk, ride_id) DO UPDATE" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "IS DISTINCT FROM" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
grep -q "duration_minutes" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"
if grep -Eq "<type>(DBLookup|InsertUpdate)</type>" "$PIPE_DIR/03_merge_trip_buffer_to_nds.hpl"; then
  echo "Trip merge pipeline must remain a set-based ExecSql operation" >&2
  exit 1
fi
grep -q "<type>GetVariable</type>" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "<from>Read StagingDB to NDS candidate counts</from><to>Get ETL_STAGINGDB_TO_NDS_STARTED_AT</to>" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "<from>Get ETL_STAGINGDB_TO_NDS_STARTED_AT</from><to>Add NDS audit fields</to>" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
if grep -q "<type>JoinRows</type>" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"; then
  echo "NDS audit must append GetVariable fields directly without JoinRows temp files" >&2
  exit 1
fi
grep -q "etl_stagingdb_to_nds" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "control.etl_job_log" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "total_rows_count" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "success_rows_count" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "failed_rows_count" "$PIPE_DIR/04_audit_stagingdb_to_nds_job_log.hpl"
grep -q "<type>ExecSql</type>" "$PIPE_DIR/05_cleanup_nds_trip_buffer.hpl"
grep -q "TRUNCATE TABLE import.stg_trip" "$PIPE_DIR/05_cleanup_nds_trip_buffer.hpl"
grep -q "<type>ExecSql</type>" "$PIPE_DIR/05_cleanup_staging_after_nds.hpl"
for table in \
  "raw_divvy_trips" \
  "raw_citibike_trips" \
  "raw_noaa_weather" \
  "raw_gbfs_station" \
  "stg_divvy_trips" \
  "stg_citibike_trips" \
  "stg_weather" \
  "stg_gbfs_station"; do
  grep -q "$table" "$PIPE_DIR/05_cleanup_staging_after_nds.hpl"
done
if grep -Eq "dq_|etl_job_log|etl_extraction_control" "$PIPE_DIR/05_cleanup_staging_after_nds.hpl"; then
  echo "Cleanup pipeline must not clear DQ or control audit tables" >&2
  exit 1
fi

TRIP_BUFFER_DDL="$ROOT/B_databases/B2_dw_nds_postgresql/05_import_trip_buffer.sql"
test -f "$TRIP_BUFFER_DDL"
grep -q "CREATE UNLOGGED TABLE import.stg_trip" "$TRIP_BUFFER_DDL"
grep -q "ALTER TABLE import.stg_trip OWNER TO hop_nds_user" "$TRIP_BUFFER_DDL"
grep -q "GRANT SELECT, INSERT, TRUNCATE ON TABLE import.stg_trip TO hop_nds_user" "$TRIP_BUFFER_DDL"

grep -q "Trip buffer guard failed" "$RUNTIME_SCRIPT"
grep -q "ON CONFLICT (city_sk, ride_id) DO UPDATE" "$RUNTIME_SCRIPT"
grep -q "IS DISTINCT FROM" "$RUNTIME_SCRIPT"
grep -q "TRUNCATE TABLE import.stg_trip" "$RUNTIME_SCRIPT"
