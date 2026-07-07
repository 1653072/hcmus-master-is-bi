#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPE_DIR="$ROOT/D_pipelines/02_ETL_StagingDB_To_NDS"
WORKFLOW="$ROOT/E_workflows/02_etl_stagingdb_to_nds.hwf"
RUNTIME_SCRIPT="$ROOT/scripts/run_staging_to_nds.sh"

test -d "$PIPE_DIR"
test -f "$WORKFLOW"
test -f "$RUNTIME_SCRIPT"
test -x "$RUNTIME_SCRIPT"
xmllint --noout "$WORKFLOW" >/dev/null

for pipeline in \
  "01_load_gbfs_station_to_nds.hpl" \
  "02_load_weather_to_nds.hpl" \
  "03_load_trips_to_nds.hpl"; do
  path="$PIPE_DIR/$pipeline"
  test -f "$path"
  xmllint --noout "$path" >/dev/null
done

grep -q "stg_gbfs_station" "$PIPE_DIR/01_load_gbfs_station_to_nds.hpl"
grep -q "nds.station" "$PIPE_DIR/01_load_gbfs_station_to_nds.hpl"
grep -q "stg_weather" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "weather_category" "$PIPE_DIR/02_load_weather_to_nds.hpl"
grep -q "stg_divvy_trips" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "stg_citibike_trips" "$PIPE_DIR/03_load_trips_to_nds.hpl"
grep -q "duration_minutes" "$PIPE_DIR/03_load_trips_to_nds.hpl"
