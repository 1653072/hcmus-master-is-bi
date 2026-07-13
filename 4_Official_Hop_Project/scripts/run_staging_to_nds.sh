#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOP_RUN="${HOP_RUN:-$(command -v hop-run.sh 2>/dev/null || command -v hop-run 2>/dev/null || true)}"
HOP_PROJECT="${HOP_PROJECT:-hcmus-bi}"
HOP_ENVIRONMENT="${HOP_ENVIRONMENT:-dev}"

if [ -z "$HOP_RUN" ]; then
  echo "Apache Hop CLI is required. Set HOP_RUN=/path/to/hop-run.sh." >&2
  exit 1
fi

cd "$ROOT"
exec "$HOP_RUN" \
  -j "$HOP_PROJECT" \
  -e "$HOP_ENVIRONMENT" \
  -r local \
  -f E_workflows/02_etl_stagingdb_to_nds.hwf
