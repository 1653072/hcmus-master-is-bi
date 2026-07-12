#!/usr/bin/env bash
# setup_project_home.sh — generate development_configs.json from development_configs.local.json
#
# Source of truth (committed): development_configs.local.json  (PROJECT_HOME = "${PROJECT_HOME}")
# Generated (gitignored):      development_configs.json       (PROJECT_HOME = absolute path)
#
# Usage:
#   make setup-project-home
#   ./scripts/setup_project_home.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_CONFIG="${PROJECT_ROOT}/development_configs.local.json"
OUT_CONFIG="${PROJECT_ROOT}/development_configs.json"
PROJECT_HOME_ABS="$PROJECT_ROOT"

python_works() {
  local out
  out=$("$@" -c "import sys; print(sys.version_info[0])" 2>&1) || return 1
  if [[ "$out" == *Microsoft*Store* ]] \
    || [[ "$out" == *Microsoft* ]] \
    || [[ "$out" == *App*execution*aliases* ]]; then
    return 1
  fi
  [[ "$out" == "3" ]]
}

find_python() {
  if command -v python3 >/dev/null 2>&1 && python_works python3; then
    echo python3
    return 0
  fi
  if command -v python >/dev/null 2>&1 && python_works python; then
    echo python
    return 0
  fi
  if command -v py >/dev/null 2>&1 && python_works py -3; then
    echo "py -3"
    return 0
  fi
  echo "ERROR: python3, python or py not found." >&2
  return 1
}

generate_config() {
  local python_cmd
  python_cmd="$(find_python)" || exit 1
  # shellcheck disable=SC2086
  $python_cmd - "$LOCAL_CONFIG" "$OUT_CONFIG" "$PROJECT_HOME_ABS" <<'PY'
import json
import sys
from pathlib import Path

local_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
project_home = sys.argv[3]

if not local_path.is_file():
    sys.exit(f"Missing template: {local_path}")

data = json.loads(local_path.read_text(encoding="utf-8"))
found = False
for var in data.get("variables", []):
    if var.get("name") == "PROJECT_HOME":
        var["value"] = project_home
        found = True
        break

if not found:
    sys.exit("PROJECT_HOME not found in development_configs.local.json")

lines = ['{\n  "variables" : [\n']
for i, var in enumerate(data["variables"]):
    line = (
        '    { "name" : '
        + json.dumps(var["name"], ensure_ascii=False)
        + ', "value" : '
        + json.dumps(var["value"], ensure_ascii=False)
        + ', "description" : '
        + json.dumps(var["description"], ensure_ascii=False)
        + " }"
    )
    if i < len(data["variables"]) - 1:
        line += ","
    lines.append(line + "\n")
lines.append("  ]\n}\n")
out_path.write_text("".join(lines), encoding="utf-8")
print(f"Generated {out_path.name} from {local_path.name}")
print(f"PROJECT_HOME -> {project_home}")
PY
}

main() {
  case "${1:-}" in
    --help|-h)
      echo "Usage: make setup-project-home  OR  ./scripts/setup_project_home.sh"
      ;;
    *)
      generate_config
      ;;
  esac
}

main "$@"
