#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if grep -RInE '([A-Za-z]:/|[A-Za-z]:\\|/Users/|/home/|/Volumes/)' \
  "$ROOT/project-config.json" \
  "$ROOT/E_workflows" \
  "$ROOT/D_pipelines" \
  "$ROOT/metadata"; then
  echo "Machine-specific absolute path found. Use \${PROJECT_HOME}/... paths in committed Hop files." >&2
  exit 1
fi

