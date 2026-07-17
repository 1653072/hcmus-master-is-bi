#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DDL="$ROOT/B_databases/B1_dw_stg_postgresql/05_etl_requirement_controls.sql"
PIPELINE="$ROOT/D_pipelines/01_ETL_Source_To_StagingDB/05_assess_source_change_matching_leakage.hpl"
WORKFLOW="$ROOT/E_workflows/01_etl_source_to_stagingdb.hwf"

test -f "$DDL"
test -f "$PIPELINE"
xmllint --noout "$PIPELINE" >/dev/null
xmllint --noout "$WORKFLOW" >/dev/null

# 1. Source-change detection must compare a content fingerprint, not file mtime.
grep -q "etl_source_file_manifest" "$DDL"
grep -q "etl_source_change_result" "$DDL"
grep -q "hashtextextended" "$PIPELINE"
grep -q "to_jsonb(r) - 'raw_loaded_at' - 'load_run_id' - 'source_file' - 'source_row_number'" "$PIPELINE"
grep -q 'change_type = "NEW"' "$PIPELINE"
grep -q 'change_type = "CHANGED"' "$PIPELINE"
grep -q 'change_type = "UNCHANGED"' "$PIPELINE"

# 2. Same-entity detection is city-scoped and does not auto-merge weak name matches.
grep -q "etl_entity_match_result" "$DDL"
grep -q "s.source_city_code = t.city_code" "$PIPELINE"
grep -q "EXACT_ID" "$PIPELINE"
grep -q "NORMALIZED_NAME" "$PIPELINE"
grep -q "UNMATCHED" "$PIPELINE"
grep -q "match_method &lt;&gt; 'EXACT_ID'" "$PIPELINE"

# 3. Leakage checks are temporal and parameterized.
grep -q "etl_data_leak_rule_result" "$DDL"
grep -q "LEAK_TRAIN_END" "$PIPELINE"
grep -q "LEAK_VALID_END" "$PIPELINE"
grep -q "LEAK_TEST_END" "$PIPELINE"
grep -q "FUTURE_RECORD_AFTER_ETL_CUTOFF" "$PIPELINE"
grep -q "TRIP_END_CROSSES_TRAIN_CUTOFF" "$PIPELINE"
grep -q "TEMPORAL_SPLIT_ORDER" "$PIPELINE"

# The control gate must run after all source branches join and before DQ audit.
grep -q "<from>Join</from>" "$WORKFLOW"
grep -q "<to>05_assess_source_change_matching_leakage.hpl</to>" "$WORKFLOW"
grep -q "<from>05_assess_source_change_matching_leakage.hpl</from>" "$WORKFLOW"
grep -q "<to>05_audit_dq_rule_results.hpl</to>" "$WORKFLOW"

echo "ETL source-change/entity-match/leakage controls: PASS"
