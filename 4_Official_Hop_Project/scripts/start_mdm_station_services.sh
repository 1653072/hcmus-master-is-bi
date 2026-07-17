#!/usr/bin/env bash
# start_mdm_station_services.sh — find hop-server.sh, start Hop Server + Go MDM station pusher.
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
#   SKIP_GO_PUSH=1              — start Hop Server only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

HOP_MDM_API_HOST="${HOP_MDM_API_HOST:-127.0.0.1}"
HOP_MDM_API_PORT="${HOP_MDM_API_PORT:-8080}"
# Defaults match hop-config.json projectConfigurations / lifecycleEnvironments for this repo
HOP_PROJECT_NAME="${HOP_PROJECT_NAME:-HCMUS_Master_IS_BI_Hop_ETL_Official}"
HOP_ENVIRONMENT_NAME="${HOP_ENVIRONMENT_NAME:-Hop_ETL_Official_Configs}"

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

HOP_SERVER="$(find_hop_server)" || {
  echo "ERROR: hop-server.sh not found. Set HOP_HOME to your Apache Hop install." >&2
  exit 1
}

HOP_INSTALL_DIR="$(cd "$(dirname "$HOP_SERVER")" && pwd)"
export HOP_CONFIG_FOLDER="${HOP_CONFIG_FOLDER:-$HOP_INSTALL_DIR/config}"

echo "Using hop-server: $HOP_SERVER"
echo "HOP_CONFIG_FOLDER=$HOP_CONFIG_FOLDER"
echo "Project=$HOP_PROJECT_NAME env=$HOP_ENVIRONMENT_NAME host=$HOP_MDM_API_HOST port=$HOP_MDM_API_PORT"

# Ensure development_configs.json exists with absolute PROJECT_HOME
if [[ -x "$SCRIPT_DIR/setup_project_home.sh" ]]; then
  "$SCRIPT_DIR/setup_project_home.sh" || true
fi

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

# Give Jetty a moment
sleep 3

if [[ "${SKIP_GO_PUSH:-0}" == "1" ]]; then
  echo "SKIP_GO_PUSH=1 — Hop Server only. Press Ctrl+C to stop."
  wait "$HOP_PID"
  exit 0
fi

cd "$PROJECT_ROOT/C_backend/C1_mdm_station_info"
echo "Starting Go MDM station pusher (go run .)"
if [[ "$#" -eq 0 ]]; then
  echo "No flags passed — default: -city ALL -operation INSERT (CHI*→CHI, else→NYC per station)"
  set -- -city ALL -operation INSERT
else
  echo "Args: $*"
fi
go run . "$@"
