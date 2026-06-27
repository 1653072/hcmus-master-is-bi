#!/usr/bin/env bash
# Validate Apache Hop .hpl pipeline XML (well-formed + common project pitfalls).
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to.hpl> [more.hpl ...]" >&2
  exit 1
fi

status=0
for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: not found: $f" >&2
    status=1
    continue
  fi

  if ! xmllint --noout "$f" 2>/dev/null; then
    echo "FAIL (XML): $f" >&2
    xmllint --noout "$f" 2>&1 || true
    status=1
    continue
  fi

  warnings=0
  if grep -q '<files/>' "$f" || grep -q '<fields/>' "$f"; then
    echo "WARN: $f has empty <files/> or <fields/> — TextFileInput2 may fail at runtime" >&2
    warnings=1
  fi

  if grep -q 'Add batch_id' "$f" && grep -q 'Constant' "$f"; then
    if ! grep -q 'STAGING_BATCH_ID' "$f" || ! grep -q '<use_formatting>Y</use_formatting>' "$f"; then
      echo "WARN: $f has Constant batch_id but may miss STAGING_BATCH_ID or use_formatting=Y" >&2
      warnings=1
    fi
  fi

  if [[ $warnings -eq 0 ]]; then
    echo "OK: $f"
  else
    status=1
  fi
done

exit $status
