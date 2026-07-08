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
  if ! grep -Eq '<type>(TableInput|TableOutput|InsertUpdate|DBLookup|FilterRows|SelectValues|Constant|RowGenerator|ScriptValueMod|TextFileInput2|JsonInput)</type>' "$path"; then
    echo "Expected a real transform in $path" >&2
    exit 1
  fi
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
if grep -q '<type>PIPELINE</type>' "$DDS_WORKFLOW"; then
  echo "DDS workflow skeleton must not call a real DDS pipeline yet: $DDS_WORKFLOW" >&2
  exit 1
fi

for pipeline in \
  "01_load_gbfs_station_to_nds.hpl" \
  "02_load_weather_to_nds.hpl" \
  "03_load_trips_to_nds.hpl"; do
  path="$PIPE_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
  assert_has_real_transform "$path"
done

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
grep -q "duration_minutes" "$PIPE_DIR/03_load_trips_to_nds.hpl"
