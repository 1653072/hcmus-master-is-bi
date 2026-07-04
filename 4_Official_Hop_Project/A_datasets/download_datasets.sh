#!/usr/bin/env bash
# Tải raw datasets: Divvy, Citi Bike, NOAA LCD v2 (Chicago + NYC).
# Mặc định: 202601–202605 (01–05/2026) theo official_topic.md
#
# Hỗ trợ: macOS, Linux, Windows (Git Bash — cần curl, Python 3.8+, unzip khi --extract)
#
# Windows: cài Python từ https://www.python.org/downloads/ (tick "Add to PATH").
#   Hoặc dùng launcher: py -3. Tắt alias python.exe trong App execution aliases nếu chỉ thấy Microsoft Store stub.
#
# Usage:
#   bash download_datasets.sh                    # hoặc ./download_datasets.sh (Unix)
#   bash download_datasets.sh --extract
#   bash download_datasets.sh --gbfs
#   bash download_datasets.sh --urls-only
#   bash download_datasets.sh --from 202603 --to 202604
#
# Biến môi trường:
#   SAMPLE_YEAR=2026

set -euo pipefail

# Windows/Git: file checkout CRLF làm bash lỗi cú pháp (vd. "unexpected token from" ở case)
if grep -q $'\r' "$0" 2>/dev/null; then
  exec bash <(tr -d '\r' < "$0") "$@"
fi

# Windows/Git: loại bỏ CR (\r) — tránh curl "(3) URL rejected: Malformed input"
strip_cr() {
  printf '%s' "$1" | tr -d '\r'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}"

DIVVY_DIR="${ROOT}/A2_divvy"
CITI_DIR="${ROOT}/A1_citibike"
NOAA_DIR="${ROOT}/A3_noaa_lcd_v2"
GBFS_DIR="${ROOT}/A4_mdm_station_info"
MANIFEST="${ROOT}/manifest.json"

SAMPLE_YEAR="${SAMPLE_YEAR:-2026}"
FROM_YM="${SAMPLE_YEAR}01"
TO_YM="${SAMPLE_YEAR}05"
EXTRACT=false
GBFS=false
URLS_ONLY=false
NOAA_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extract) EXTRACT=true; shift ;;
    --gbfs) GBFS=true; shift ;;
    --urls-only) URLS_ONLY=true; shift ;;
    --noaa-only) NOAA_ONLY=true; shift ;;
    --from) FROM_YM="$(strip_cr "$2")"; shift 2 ;;
    --to) TO_YM="$(strip_cr "$2")"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Portable helpers (macOS / Linux / Git Bash on Windows) ---

# Mảng lệnh Python đã xác minh, vd: (python3) hoặc (py -3)
RUN_PYTHON=()

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

init_python() {
  local -a candidates=()
  if [[ -n "${PYTHON:-}" ]]; then
    if [[ "$PYTHON" == *" "* ]]; then
      candidates+=("$PYTHON")
    else
      candidates+=("$PYTHON")
    fi
  fi
  if [[ "${OS:-}" == "Windows_NT" ]] || uname -s 2>/dev/null | grep -qiE 'MINGW|MSYS|CYGWIN'; then
    candidates+=("py -3" python3 python)
  else
    candidates+=(python3 "py -3" python)
  fi

  local c args
  for c in "${candidates[@]}"; do
    if [[ "$c" == *" "* ]]; then
      # shellcheck disable=SC2206
      args=($c)
    else
      args=("$c")
    fi
    command -v "${args[0]}" >/dev/null 2>&1 || continue
    if python_works "${args[@]}"; then
      RUN_PYTHON=("${args[@]}")
      return 0
    fi
  done

  cat >&2 <<'EOF'
[error] Khong tim thay Python 3.8+.

  macOS/Linux:  python3 --version
  Windows:      cai tu https://www.python.org/downloads/ (tick "Add python.exe to PATH")
                hoac chay: py -3 --version
                tat alias python.exe / python3.exe trong:
                  Settings → Apps → Advanced app settings → App execution aliases

  Sau khi cai, thu lai: make datasets-full
EOF
  exit 49
}

run_python() {
  "${RUN_PYTHON[@]}" "$@"
}

init_python
printf '[info] Python: %s\n' "${RUN_PYTHON[*]}"

require_cmd() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "[error] Thiếu lệnh: ${missing[*]}" >&2
    echo "        Windows: cài Git for Windows (Git Bash) và bật curl trong PATH." >&2
    exit 1
  fi
}

file_size() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo 0
    return 0
  fi
  run_python - "$f" <<'PY'
import os, sys
print(os.path.getsize(sys.argv[1]))
PY
}

utc_now_iso() {
  if date -u +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -u +"%Y-%m-%dT%H:%M:%SZ"
  else
    run_python - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
  fi
}

summarize_a_dirs() {
  run_python - "$ROOT" <<'PY'
import glob, os, sys

root = sys.argv[1]
for path in sorted(glob.glob(os.path.join(root, "A*"))):
    if not os.path.isdir(path):
        continue
    total = 0
    for dirpath, _, files in os.walk(path):
        for name in files:
            try:
                total += os.path.getsize(os.path.join(dirpath, name))
            except OSError:
                pass
    mb = total / (1024 * 1024)
    print(f"{mb:8.1f} MB  {os.path.basename(path)}")
PY
}

require_cmd curl
if $EXTRACT && ! $URLS_ONLY; then
  require_cmd unzip
fi

NOAA_BASE="https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/${SAMPLE_YEAR}"
NOAA_CHI_ID="USW00014819"
NOAA_NYC_ID="USW00094728"
NOAA_CHI_URL="${NOAA_BASE}/LCD_${NOAA_CHI_ID}_${SAMPLE_YEAR}.csv"
NOAA_NYC_URL="${NOAA_BASE}/LCD_${NOAA_NYC_ID}_${SAMPLE_YEAR}.csv"

NOAA_CHI_RAW="${NOAA_DIR}/LCD_${NOAA_CHI_ID}_${SAMPLE_YEAR}.csv"
NOAA_NYC_RAW="${NOAA_DIR}/LCD_${NOAA_NYC_ID}_${SAMPLE_YEAR}.csv"
NOAA_CHI_FILTERED="${NOAA_DIR}/LCD_${NOAA_CHI_ID}_${SAMPLE_YEAR}_01-05.csv"
NOAA_NYC_FILTERED="${NOAA_DIR}/LCD_${NOAA_NYC_ID}_${SAMPLE_YEAR}_01-05.csv"

GBFS_CHI_URL="https://gbfs.lyft.com/gbfs/2.3/chi/en/station_information.json"
GBFS_NYC_URL="https://gbfs.citibikenyc.com/gbfs/en/station_information.json"

mkdir -p "${DIVVY_DIR}" "${CITI_DIR}" "${NOAA_DIR}" "${GBFS_DIR}"

month_range() {
  local from="$1" to="$2"
  FROM_YM="$(strip_cr "$from")" TO_YM="$(strip_cr "$to")" run_python - <<'PY'
import os, sys
from datetime import date

from_ = os.environ["FROM_YM"].strip("\r\n")
to_ = os.environ["TO_YM"].strip("\r\n")
y, m = int(from_[:4]), int(from_[4:6])
y2, m2 = int(to_[:4]), int(to_[4:6])
d = date(y, m, 1)
end = date(y2, m2, 1)
while d <= end:
    sys.stdout.write(f"{d.year}{d.month:02d}\n")
    if d.month == 12:
        d = date(d.year + 1, 1, 1)
    else:
        d = date(d.year, d.month + 1, 1)
PY
}

download() {
  local url dest
  url="$(strip_cr "$1")"
  dest="$(strip_cr "$2")"
  if $URLS_ONLY; then
    printf '[check] %s -> ' "$url"
    curl -sfI "$url" | head -1
    return 0
  fi
  if [[ -f "$dest" ]]; then
    printf '[skip] Da co: %s\n' "$dest"
    return 0
  fi
  printf '[get]  %s\n' "$url"
  printf '       -> %s\n' "$dest"
  curl -fL --retry 3 --continue-at - -o "$dest" "$url"
}

filter_noaa_jan_may() {
  local src="$1"
  local dest="$2"
  local year="$3"
  if $URLS_ONLY; then
    echo "[check] filter NOAA -> $dest (from $src)"
    return 0
  fi
  if [[ ! -f "$src" ]]; then
    echo "[error] Thieu file NOAA bulk: $src" >&2
    exit 1
  fi
  echo "[filter] ${year}-01 .. ${year}-05 -> $dest"
  SRC="$src" DEST="$dest" YEAR="$year" run_python - <<'PY'
import csv, os

src = os.environ["SRC"]
dest = os.environ["DEST"]
year = os.environ["YEAR"]
start = f"{year}-01-01"

with open(src, newline="", encoding="utf-8") as fin, open(dest, "w", newline="", encoding="utf-8") as fout:
    reader = csv.DictReader(fin)
    writer = csv.DictWriter(fout, fieldnames=reader.fieldnames, quoting=csv.QUOTE_ALL)
    writer.writeheader()
    kept = 0
    for row in reader:
        d = row.get("DATE", "")[:10]
        if d and start <= d <= f"{year}-05-31":
            writer.writerow(row)
            kept += 1
print(f"       kept {kept} rows")
PY
}

echo "=== Bike-share raw download (trip ${FROM_YM}-${TO_YM}, NOAA LCD v2 year=${SAMPLE_YEAR}, filter 01-05) ==="

TRIP_FILES=()
if ! $NOAA_ONLY; then
while IFS= read -r ym || [[ -n "${ym:-}" ]]; do
  ym="$(strip_cr "$ym")"
  [[ -z "$ym" ]] && continue
  divvy_url="https://divvy-tripdata.s3.amazonaws.com/${ym}-divvy-tripdata.zip"
  citi_url="https://s3.amazonaws.com/tripdata/${ym}-citibike-tripdata.zip"
  divvy_zip="${DIVVY_DIR}/${ym}-divvy-tripdata.zip"
  citi_zip="${CITI_DIR}/${ym}-citibike-tripdata.zip"

  download "$divvy_url" "$divvy_zip"
  download "$citi_url" "$citi_zip"
  TRIP_FILES+=("$ym")

  if $EXTRACT && ! $URLS_ONLY; then
    divvy_out="${DIVVY_DIR}/extracted/${ym}"
    citi_out="${CITI_DIR}/extracted/${ym}"
    mkdir -p "$divvy_out" "$citi_out"
    echo "[unzip] Divvy $ym"
    unzip -o -q "$divvy_zip" -d "$divvy_out"
    echo "[unzip] Citi Bike $ym"
    unzip -o -q "$citi_zip" -d "$citi_out"
  fi
done < <(month_range "$FROM_YM" "$TO_YM")
fi

download "$NOAA_CHI_URL" "$NOAA_CHI_RAW"
download "$NOAA_NYC_URL" "$NOAA_NYC_RAW"
filter_noaa_jan_may "$NOAA_CHI_RAW" "$NOAA_CHI_FILTERED" "$SAMPLE_YEAR"
filter_noaa_jan_may "$NOAA_NYC_RAW" "$NOAA_NYC_FILTERED" "$SAMPLE_YEAR"

if $GBFS; then
  download "$GBFS_CHI_URL" "${GBFS_DIR}/divvy_station_information.json"
  download "$GBFS_NYC_URL" "${GBFS_DIR}/citibike_station_information.json"
fi

if $URLS_ONLY; then
  echo "=== URL check hoan tat ==="
  exit 0
fi

DOWNLOADED_AT="$(utc_now_iso)"
TRIP_JSON=""
if [[ ${#TRIP_FILES[@]} -gt 0 ]]; then
for i in "${!TRIP_FILES[@]}"; do
  ym="${TRIP_FILES[$i]}"
  divvy_zip="${DIVVY_DIR}/${ym}-divvy-tripdata.zip"
  citi_zip="${CITI_DIR}/${ym}-citibike-tripdata.zip"
  divvy_bytes="$(file_size "$divvy_zip")"
  citi_bytes="$(file_size "$citi_zip")"
  comma=","
  [[ $i -eq $((${#TRIP_FILES[@]} - 1)) ]] && comma=""
  TRIP_JSON="${TRIP_JSON}
    {\"month\": \"${ym}\", \"divvy_zip\": \"A2_divvy/${ym}-divvy-tripdata.zip\", \"divvy_bytes\": ${divvy_bytes}, \"citibike_zip\": \"A1_citibike/${ym}-citibike-tripdata.zip\", \"citibike_bytes\": ${citi_bytes}}${comma}"
done
fi

TRIP_MONTHS_JSON=""
if [[ ${#TRIP_FILES[@]} -gt 0 ]]; then
  TRIP_MONTHS_JSON=$(printf '"%s",' "${TRIP_FILES[@]}" | sed 's/,$//')
fi

chi_raw_bytes="$(file_size "$NOAA_CHI_RAW")"
nyc_raw_bytes="$(file_size "$NOAA_NYC_RAW")"
chi_filt_bytes="$(file_size "$NOAA_CHI_FILTERED")"
nyc_filt_bytes="$(file_size "$NOAA_NYC_FILTERED")"

cat > "$MANIFEST" <<EOF
{
  "sample_period": "${SAMPLE_YEAR}-01_to_${SAMPLE_YEAR}-05",
  "trip_months": [${TRIP_MONTHS_JSON}],
  "downloaded_at_utc": "${DOWNLOADED_AT}",
  "noaa_lcd_version": "v2",
  "noaa_lcd_v1_deprecated": "2025-08-29",
  "trip_files": [${TRIP_JSON}
  ],
  "noaa_files": [
    {
      "city": "CHI",
      "station_id_v2": "${NOAA_CHI_ID}",
      "station_id_v1_legacy": "72534014819",
      "name": "CHICAGO MIDWAY AP, IL US",
      "bulk_path": "A3_noaa_lcd_v2/LCD_${NOAA_CHI_ID}_${SAMPLE_YEAR}.csv",
      "filtered_path": "A3_noaa_lcd_v2/LCD_${NOAA_CHI_ID}_${SAMPLE_YEAR}_01-05.csv",
      "url": "${NOAA_CHI_URL}",
      "raw_bytes": ${chi_raw_bytes},
      "filtered_bytes": ${chi_filt_bytes}
    },
    {
      "city": "NYC",
      "station_id_v2": "${NOAA_NYC_ID}",
      "station_id_v1_legacy": "72505394728",
      "name": "NY CITY CENTRAL PARK, NY US",
      "bulk_path": "A3_noaa_lcd_v2/LCD_${NOAA_NYC_ID}_${SAMPLE_YEAR}.csv",
      "filtered_path": "A3_noaa_lcd_v2/LCD_${NOAA_NYC_ID}_${SAMPLE_YEAR}_01-05.csv",
      "url": "${NOAA_NYC_URL}",
      "raw_bytes": ${nyc_raw_bytes},
      "filtered_bytes": ${nyc_filt_bytes}
    }
  ]
}
EOF

echo "=== Hoan tat. Manifest: $MANIFEST ==="
summarize_a_dirs
