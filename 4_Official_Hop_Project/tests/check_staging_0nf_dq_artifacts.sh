#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_SQL="$ROOT/B_databases/B1_dw_stg_postgresql/02_staging_schema.sql"
CONTROL_SQL="$ROOT/B_databases/B1_dw_stg_postgresql/03_control_schema.sql"
DQ_SQL="$ROOT/B_databases/B1_dw_stg_postgresql/06_dq_schema.sql"
RUNTIME_SCRIPT="$ROOT/scripts/run_staging_0nf_dq.sh"
PIPE_DIR="$ROOT/D_pipelines/01_ETL_Source_To_StagingDB"
WORKFLOW="$ROOT/E_workflows/01_etl_source_to_stagingdb.hwf"

assert_no_shell_blackbox() {
  local path="$1"
  if grep -q '<type>SHELL</type>' "$path" || grep -q 'scripts/run_' "$path"; then
    echo "Unexpected shell blackbox references remain in $path" >&2
    exit 1
  fi
}

assert_has_real_transform() {
  local path="$1"
  if ! grep -Eq '<type>(TableInput|TableOutput|InsertUpdate|DBLookup|FilterRows|SelectValues|Constant|RowGenerator|ScriptValueMod|TextFileInput2|JsonInput)</type>' "$path"; then
    echo "Expected a real transform in $path" >&2
    exit 1
  fi
}

test -f "$DQ_SQL"
test -f "$RUNTIME_SCRIPT"
test -x "$RUNTIME_SCRIPT"
test -d "$PIPE_DIR"
test -f "$WORKFLOW"
xmllint --noout "$WORKFLOW" >/dev/null
assert_no_shell_blackbox "$WORKFLOW"

required_stg_tables=(
  "stg_divvy_trips"
  "stg_citibike_trips"
  "stg_weather"
  "stg_gbfs_station"
)

for table in "${required_stg_tables[@]}"; do
  grep -q "CREATE TABLE staging.${table}" "$STAGING_SQL"
  if ! awk "/CREATE TABLE staging\\.${table}/,/;/" "$STAGING_SQL" | grep -q "PRIMARY KEY"; then
    echo "Staging table $table must define a primary key" >&2
    exit 1
  fi
done

grep -q "CREATE TABLE staging.dq_reject_row" "$DQ_SQL"
grep -q "CREATE TABLE staging.dq_warning_row" "$DQ_SQL"
grep -q "CREATE TABLE control.etl_dq_rule_result" "$CONTROL_SQL"
grep -q "CREATE TABLE control.dq_rule_catalog" "$CONTROL_SQL"

grep -q "DIVVY_NULL_REQUIRED" "$CONTROL_SQL"
grep -q "CITI_DUPLICATE_RIDE" "$CONTROL_SQL"
grep -q "NOAA_FORMAT_REPORT_TYPE" "$CONTROL_SQL"
grep -q "GBFS_DATATYPE_CAPACITY" "$CONTROL_SQL"

for pipeline in \
  "01_validate_divvy_raw_to_staging.hpl" \
  "02_validate_citibike_raw_to_staging.hpl" \
  "03_validate_noaa_raw_to_staging.hpl" \
  "04_validate_gbfs_raw_to_staging.hpl" \
  "05_audit_dq_rule_results.hpl"; do
  path="$PIPE_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
  assert_has_real_transform "$path"
done
