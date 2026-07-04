#!/usr/bin/env bash
# Tải raw datasets: Divvy, Citi Bike, NOAA LCD v2 (Chicago + NYC).
# Mặc định: 202601–202605 (01–05/2026) theo official_topic.md
#
# Usage:
#   ./download_datasets.sh                    # tải 5 tháng trip + NOAA v2, lọc NOAA 01–05/2026
#   ./download_datasets.sh --extract            # thêm giải nén ZIP trip
#   ./download_datasets.sh --gbfs               # thêm GBFS station_information (A4)
#   ./download_datasets.sh --urls-only          # chỉ kiểm tra HTTP (validate)
#   ./download_datasets.sh --from 202603 --to 202604
#
# Biến môi trường:
#   SAMPLE_YEAR=2026   (mặc định 2026 — NOAA LCD v2 bulk)

set -euo pipefail

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
    --from) FROM_YM="$2"; shift 2 ;;
    --to) TO_YM="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

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
  python3 - <<PY
from datetime import date
y, m = int("${from}"[:4]), int("${from}"[4:6])
y2, m2 = int("${to}"[:4]), int("${to}"[4:6])
d = date(y, m, 1)
end = date(y2, m2, 1)
while d <= end:
    print(f"{d.year}{d.month:02d}")
    if d.month == 12:
        d = date(d.year + 1, 1, 1)
    else:
        d = date(d.year, d.month + 1, 1)
PY
}

download() {
  local url="$1"
  local dest="$2"
  if $URLS_ONLY; then
    echo -n "[check] $url -> "
    curl -sfI "$url" | head -1
    return 0
  fi
  if [[ -f "$dest" ]]; then
    echo "[skip] Đã có: $dest"
    return 0
  fi
  echo "[get]  $url"
  echo "       -> $dest"
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
    echo "[error] Thiếu file NOAA raw: $src" >&2
    exit 1
  fi
  echo "[filter] ${year}-01 .. ${year}-05 -> $dest"
  SRC="$src" DEST="$dest" YEAR="$year" python3 - <<'PY'
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

echo "=== Bike-share raw download (trip ${FROM_YM}–${TO_YM}, NOAA LCD v2 year=${SAMPLE_YEAR}, filter 01–05) ==="

TRIP_FILES=()
if ! $NOAA_ONLY; then
while IFS= read -r ym; do
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
  echo "=== URL check hoàn tất ==="
  exit 0
fi

DOWNLOADED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TRIP_JSON=""
if [[ ${#TRIP_FILES[@]} -gt 0 ]]; then
for i in "${!TRIP_FILES[@]}"; do
  ym="${TRIP_FILES[$i]}"
  divvy_zip="${DIVVY_DIR}/${ym}-divvy-tripdata.zip"
  citi_zip="${CITI_DIR}/${ym}-citibike-tripdata.zip"
  divvy_bytes=$(stat -f%z "$divvy_zip" 2>/dev/null || stat -c%s "$divvy_zip")
  citi_bytes=$(stat -f%z "$citi_zip" 2>/dev/null || stat -c%s "$citi_zip")
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

chi_raw_bytes=$(stat -f%z "$NOAA_CHI_RAW" 2>/dev/null || stat -c%s "$NOAA_CHI_RAW")
nyc_raw_bytes=$(stat -f%z "$NOAA_NYC_RAW" 2>/dev/null || stat -c%s "$NOAA_NYC_RAW")
chi_filt_bytes=$(stat -f%z "$NOAA_CHI_FILTERED" 2>/dev/null || stat -c%s "$NOAA_CHI_FILTERED")
nyc_filt_bytes=$(stat -f%z "$NOAA_NYC_FILTERED" 2>/dev/null || stat -c%s "$NOAA_NYC_FILTERED")

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

echo "=== Hoàn tất. Manifest: $MANIFEST ==="
du -sh "${ROOT}"/A* 2>/dev/null || true
