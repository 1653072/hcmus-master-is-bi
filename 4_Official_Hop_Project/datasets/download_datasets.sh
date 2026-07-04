#!/usr/bin/env bash
# Tải raw datasets cho đề tài bike-share (Divvy, Citi Bike, NOAA LCD).
# Mặc định: tháng mẫu 2024-06 theo official_topic.md
#
# Usage:
#   ./download_datasets.sh              # YYYYMM=202406
#   ./download_datasets.sh 202406         # chỉ định tháng trip
#   ./download_datasets.sh 202406 --extract   # giải nén ZIP trip vào raw/*/extracted/
#   SAMPLE_YEAR=2024 ./download_datasets.sh   # NOAA theo năm (mặc định 2024)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_DIR="${SCRIPT_DIR}/raw"
YM="${1:-202406}"
EXTRACT=false
if [[ "${2:-}" == "--extract" ]]; then
  EXTRACT=true
fi

YEAR="${SAMPLE_YEAR:-${YM:0:4}}"
MONTH="${YM:4:2}"

DIVVY_URL="https://divvy-tripdata.s3.amazonaws.com/${YM}-divvy-tripdata.zip"
CITI_URL="https://s3.amazonaws.com/tripdata/${YM}-citibike-tripdata.zip"
NOAA_CHI_URL="https://www.ncei.noaa.gov/data/local-climatological-data/access/${YEAR}/72534014819.csv"
NOAA_NYC_URL="https://www.ncei.noaa.gov/data/local-climatological-data/access/${YEAR}/72505394728.csv"

DIVVY_ZIP="${RAW_DIR}/divvy/trips/${YM}-divvy-tripdata.zip"
CITI_ZIP="${RAW_DIR}/citibike/trips/${YM}-citibike-tripdata.zip"
NOAA_CHI_CSV="${RAW_DIR}/noaa/lcd/${YEAR}/72534014819.csv"
NOAA_NYC_CSV="${RAW_DIR}/noaa/lcd/${YEAR}/72505394728.csv"
MANIFEST="${SCRIPT_DIR}/manifest.json"

mkdir -p "$(dirname "$DIVVY_ZIP")" "$(dirname "$CITI_ZIP")" "$(dirname "$NOAA_CHI_CSV")"

download() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "[skip] Đã có: $dest"
    return 0
  fi
  echo "[get]  $url"
  echo "       -> $dest"
  curl -fL --retry 3 --continue-at - -o "$dest" "$url"
}

echo "=== Bike-share raw download (YYYYMM=${YM}, NOAA year=${YEAR}) ==="

download "$DIVVY_URL" "$DIVVY_ZIP"
download "$CITI_URL" "$CITI_ZIP"
download "$NOAA_CHI_URL" "$NOAA_CHI_CSV"
download "$NOAA_NYC_URL" "$NOAA_NYC_CSV"

if $EXTRACT; then
  echo "=== Giải nén ZIP trip ==="
  DIVVY_OUT="${RAW_DIR}/divvy/trips/extracted/${YM}"
  CITI_OUT="${RAW_DIR}/citibike/trips/extracted/${YM}"
  mkdir -p "$DIVVY_OUT" "$CITI_OUT"
  unzip -o "$DIVVY_ZIP" -d "$DIVVY_OUT"
  unzip -o "$CITI_ZIP" -d "$CITI_OUT"
fi

# manifest.json (metadata, không hash file lớn để tránh chờ lâu)
DOWNLOADED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$MANIFEST" <<EOF
{
  "sample_period": "${YEAR}-${MONTH}",
  "downloaded_at_utc": "${DOWNLOADED_AT}",
  "files": [
    {
      "source": "divvy_trips",
      "path": "raw/divvy/trips/${YM}-divvy-tripdata.zip",
      "url": "${DIVVY_URL}",
      "bytes": $(stat -f%z "$DIVVY_ZIP" 2>/dev/null || stat -c%s "$DIVVY_ZIP")
    },
    {
      "source": "citibike_trips",
      "path": "raw/citibike/trips/${YM}-citibike-tripdata.zip",
      "url": "${CITI_URL}",
      "bytes": $(stat -f%z "$CITI_ZIP" 2>/dev/null || stat -c%s "$CITI_ZIP")
    },
    {
      "source": "noaa_lcd_chicago",
      "path": "raw/noaa/lcd/${YEAR}/72534014819.csv",
      "url": "${NOAA_CHI_URL}",
      "station": "CHICAGO MIDWAY AIRPORT, IL US",
      "bytes": $(stat -f%z "$NOAA_CHI_CSV" 2>/dev/null || stat -c%s "$NOAA_CHI_CSV")
    },
    {
      "source": "noaa_lcd_nyc",
      "path": "raw/noaa/lcd/${YEAR}/72505394728.csv",
      "url": "${NOAA_NYC_URL}",
      "station": "NY CITY CENTRAL PARK, NY US",
      "bytes": $(stat -f%z "$NOAA_NYC_CSV" 2>/dev/null || stat -c%s "$NOAA_NYC_CSV")
    }
  ]
}
EOF

echo "=== Hoàn tất. Manifest: $MANIFEST ==="
du -sh "$RAW_DIR"/* 2>/dev/null || true
