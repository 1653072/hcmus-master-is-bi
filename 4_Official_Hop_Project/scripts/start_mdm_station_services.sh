#!/usr/bin/env bash
# start_mdm_station_services.sh — find hop-server.sh, patch Hop retention, start Hop Server + Go MDM pusher.
#
# Usage (from 4_Official_Hop_Project/):
#   make mdm-start
#   ./scripts/start_mdm_station_services.sh
#
# Env overrides (optional — defaults already match Official Hop project):
#   HOP_HOME / APACHE_HOP_HOME  — Hop install directory (if auto-find fails)
#   HOP_PROJECT_NAME            — default: HCMUS_Master_IS_BI_Hop_ETL_Official
#   HOP_ENVIRONMENT_NAME        — default: Hop_ETL_Official_Configs
#   HOP_MDM_API_HOST / HOP_MDM_API_PORT
#   HOP_OPTIONS                 — JVM flags for hop-server (default: -Xmx8g)
#   MDM_KILL_EXISTING=1         — kill process listening on HOP_MDM_API_PORT before start
#   SKIP_GO_PUSH=1              — start Hop Server only
#   HOP_OBJECT_TIMEOUT_MINUTES  — default: 2  (purge completed pipeline objects)
#   HOP_LOG_TIMEOUT_MINUTES     — default: 5
#   HOP_MAX_LOG_LINES           — default: 100
#   HOP_LOGGING_REGISTRY_SIZE   — default: 200
#
# Examples:
#   make mdm-start
#   MDM_KILL_EXISTING=1 make mdm-start
#   HOP_OPTIONS="-Xmx6g" make mdm-start
#   SKIP_GO_PUSH=1 make mdm-start
#   ./scripts/start_mdm_station_services.sh -city ALL -operation INSERT -limit 20

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

HOP_MDM_API_HOST="${HOP_MDM_API_HOST:-127.0.0.1}"
HOP_MDM_API_PORT="${HOP_MDM_API_PORT:-8080}"
# Defaults match hop-config.json projectConfigurations / lifecycleEnvironments for this repo
HOP_PROJECT_NAME="${HOP_PROJECT_NAME:-HCMUS_Master_IS_BI_Hop_ETL_Official}"
HOP_ENVIRONMENT_NAME="${HOP_ENVIRONMENT_NAME:-Hop_ETL_Official_Configs}"
# hop-server.sh defaults to -Xmx2048m — too small for rapid MDM web-service pipelines
export HOP_OPTIONS="${HOP_OPTIONS:--Xmx8g}"

# Retention: each MDM POST keeps parent+child pipeline executions in Hop Server memory.
# Defaults below prevent multi-hour accumulation / Java heap space on bulk push.
HOP_OBJECT_TIMEOUT_MINUTES="${HOP_OBJECT_TIMEOUT_MINUTES:-2}"
HOP_LOG_TIMEOUT_MINUTES="${HOP_LOG_TIMEOUT_MINUTES:-5}"
HOP_MAX_LOG_LINES="${HOP_MAX_LOG_LINES:-100}"
HOP_LOGGING_REGISTRY_SIZE="${HOP_LOGGING_REGISTRY_SIZE:-200}"

find_hop_server() {
  local candidate
  for candidate in \
    "${HOP_HOME:+$HOP_HOME/hop-server.sh}" \
    "${APACHE_HOP_HOME:+$APACHE_HOP_HOME/hop-server.sh}" \
    "$HOME/Documents/7_External_Tools/apache_hop_etl_engine/hop-server.sh" \
    "$HOME/apache-hop/hop-server.sh" \
    /opt/hop/hop-server.sh \
    /usr/local/hop/hop-server.sh
  do
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v hop-server.sh >/dev/null 2>&1; then
    command -v hop-server.sh
    return 0
  fi

  if command -v mdfind >/dev/null 2>&1; then
    candidate="$(mdfind -name hop-server.sh 2>/dev/null | head -n 1 || true)"
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi

  # Bounded find as last resort
  candidate="$(find "$HOME" /opt /usr/local -name hop-server.sh -type f 2>/dev/null | head -n 1 || true)"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi

  return 1
}

# Patch the Hop install that will be started (portable across machines — no hardcoded user paths).
# Affects that Hop install globally (all projects using it) so bulk MDM push does not OOM.
apply_hop_server_retention_config() {
  local hop_install="$1"
  local config_folder="$2"
  local hop_config="${config_folder}/hop-config.json"
  local hop_server_xml="${hop_install}/hop-server.xml"

  if [[ ! -f "$hop_config" ]]; then
    hop_config="${hop_install}/config/hop-config.json"
  fi

  if [[ ! -f "$hop_config" ]]; then
    echo "WARNING: hop-config.json not found under $config_folder or $hop_install/config — skip JSON retention patch." >&2
  else
    echo "Patching Hop retention in: $hop_config"
    python3 - "$hop_config" \
      "$HOP_OBJECT_TIMEOUT_MINUTES" \
      "$HOP_LOG_TIMEOUT_MINUTES" \
      "$HOP_MAX_LOG_LINES" \
      "$HOP_LOGGING_REGISTRY_SIZE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
updates = {
    "HOP_SERVER_OBJECT_TIMEOUT_MINUTES": str(sys.argv[2]),
    "HOP_MAX_LOG_TIMEOUT_IN_MINUTES": str(sys.argv[3]),
    "HOP_MAX_LOG_SIZE_IN_LINES": str(sys.argv[4]),
    "HOP_MAX_LOGGING_REGISTRY_SIZE": str(sys.argv[5]),
}

raw = path.read_text(encoding="utf-8")
data = json.loads(raw)
variables = data.setdefault("variables", [])
by_name = {v.get("name"): v for v in variables if isinstance(v, dict) and v.get("name")}

for name, new_val in updates.items():
    old = by_name.get(name)
    if old is None:
        entry = {"name": name, "value": new_val, "description": ""}
        variables.append(entry)
        by_name[name] = entry
        print(f"  {name}: (missing) -> {new_val}")
    else:
        old_val = str(old.get("value", ""))
        if old_val != new_val:
            old["value"] = new_val
            print(f"  {name}: {old_val} -> {new_val}")
        else:
            print(f"  {name}: {new_val} (unchanged)")

path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"  Wrote {path}")
PY
  fi

  if [[ ! -f "$hop_server_xml" ]]; then
    echo "WARNING: hop-server.xml not found at $hop_server_xml — skip XML retention patch." >&2
    return 0
  fi

  echo "Patching Hop retention in: $hop_server_xml"
  python3 - "$hop_server_xml" \
    "$HOP_MAX_LOG_LINES" \
    "$HOP_LOG_TIMEOUT_MINUTES" \
    "$HOP_OBJECT_TIMEOUT_MINUTES" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
max_log_lines, log_timeout, object_timeout = sys.argv[2], sys.argv[3], sys.argv[4]
text = path.read_text(encoding="utf-8")

def replace_tag(src, tag, new_val):
    pattern = re.compile(r"(<" + tag + r">)(.*?)(</" + tag + r">)", re.DOTALL)
    m = pattern.search(src)
    if not m:
        return src, None, new_val
    old = m.group(2).strip()
    return pattern.sub(r"\g<1>" + new_val + r"\g<3>", src, count=1), old, new_val

for tag, val in (
    ("max_log_lines", max_log_lines),
    ("max_log_timeout_minutes", log_timeout),
    ("object_timeout_minutes", object_timeout),
):
    text, old, new = replace_tag(text, tag, val)
    if old is None:
        print(f"  WARNING: <{tag}> not found — skipped")
    elif old != new:
        print(f"  <{tag}>: {old} -> {new}")
    else:
        print(f"  <{tag}>: {new} (unchanged)")

path.write_text(text, encoding="utf-8")
print(f"  Wrote {path}")
PY
}

ensure_mdm_port_free() {
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  if ! lsof -nP -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi

  echo "ERROR: port $HOP_MDM_API_PORT already in use:" >&2
  lsof -nP -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN >&2 || true

  if [[ "${MDM_KILL_EXISTING:-0}" == "1" ]]; then
    echo "MDM_KILL_EXISTING=1 — stopping listener(s) on port $HOP_MDM_API_PORT ..." >&2
    # shellcheck disable=SC2046
    kill $(lsof -nP -t -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN) 2>/dev/null || true
    sleep 2
    if lsof -nP -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      # shellcheck disable=SC2046
      kill -9 $(lsof -nP -t -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN) 2>/dev/null || true
      sleep 1
    fi
    if lsof -nP -iTCP:"$HOP_MDM_API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "ERROR: could not free port $HOP_MDM_API_PORT" >&2
      exit 1
    fi
    echo "Port $HOP_MDM_API_PORT is free."
    return 0
  fi

  echo "Fix: MDM_KILL_EXISTING=1 make mdm-start" >&2
  echo "Or:  HOP_MDM_API_PORT=8081 make mdm-start" >&2
  exit 1
}

HOP_SERVER="$(find_hop_server)" || {
  echo "ERROR: hop-server.sh not found. Set HOP_HOME to your Apache Hop install." >&2
  exit 1
}

HOP_INSTALL_DIR="$(cd "$(dirname "$HOP_SERVER")" && pwd)"
export HOP_CONFIG_FOLDER="${HOP_CONFIG_FOLDER:-$HOP_INSTALL_DIR/config}"

echo "Using hop-server: $HOP_SERVER"
echo "HOP_CONFIG_FOLDER=$HOP_CONFIG_FOLDER"
echo "HOP_OPTIONS=$HOP_OPTIONS"
echo "Project=$HOP_PROJECT_NAME env=$HOP_ENVIRONMENT_NAME host=$HOP_MDM_API_HOST port=$HOP_MDM_API_PORT"
echo "Retention targets: object=${HOP_OBJECT_TIMEOUT_MINUTES}m log=${HOP_LOG_TIMEOUT_MINUTES}m max_log_lines=${HOP_MAX_LOG_LINES} registry=${HOP_LOGGING_REGISTRY_SIZE}"
echo "NOTE: retention patch applies to this Hop install (all projects using it)."

# Ensure development_configs.json exists with absolute PROJECT_HOME
if [[ -x "$SCRIPT_DIR/setup_project_home.sh" ]]; then
  "$SCRIPT_DIR/setup_project_home.sh" || true
fi

apply_hop_server_retention_config "$HOP_INSTALL_DIR" "$HOP_CONFIG_FOLDER"
ensure_mdm_port_free

cd "$HOP_INSTALL_DIR"
"$HOP_SERVER" \
  -e "$HOP_ENVIRONMENT_NAME" \
  -j "$HOP_PROJECT_NAME" \
  "$HOP_MDM_API_HOST" "$HOP_MDM_API_PORT" &
HOP_PID=$!
echo "Hop Server PID=$HOP_PID"

cleanup() {
  if kill -0 "$HOP_PID" 2>/dev/null; then
    echo "Stopping Hop Server PID=$HOP_PID"
    kill "$HOP_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Wait until Jetty answers (up to ~60s) — sleep 3 alone is often too short after cold start
echo "Waiting for Hop Server on ${HOP_MDM_API_HOST}:${HOP_MDM_API_PORT} ..."
ready=0
for _ in $(seq 1 60); do
  if curl -sf -u cluster:cluster \
    "http://${HOP_MDM_API_HOST}:${HOP_MDM_API_PORT}/hop/status/" >/dev/null 2>&1 \
    || curl -sf -u cluster:cluster \
    "http://${HOP_MDM_API_HOST}:${HOP_MDM_API_PORT}/hop/" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if ! kill -0 "$HOP_PID" 2>/dev/null; then
    echo "ERROR: Hop Server exited before becoming ready (check Java heap / port)." >&2
    exit 1
  fi
  sleep 1
done
if [[ "$ready" -ne 1 ]]; then
  echo "ERROR: Hop Server did not become ready within 60s." >&2
  exit 1
fi
echo "Hop Server is ready."

if [[ "${SKIP_GO_PUSH:-0}" == "1" ]]; then
  echo "SKIP_GO_PUSH=1 — Hop Server only. Press Ctrl+C to stop."
  wait "$HOP_PID"
  exit 0
fi

cd "$PROJECT_ROOT/C_backend/C1_mdm_station_info"
echo "Starting Go MDM station pusher (go run .)"
if [[ "$#" -eq 0 ]]; then
  echo "No flags passed — default: -city ALL -operation INSERT (all stations; pass -limit N to cap)"
  set -- -city ALL -operation INSERT
else
  echo "Args: $*"
fi
go run . "$@"
