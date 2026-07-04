# Datasets — Phân tích và hướng dẫn tải raw

Tài liệu này bổ sung [official_topic.md](../../0_topic_exploration/official_topic.md) mục 5: phân tích chuyên sâu **ba nguồn chính** (Divvy, Citi Bike, NOAA LCD), cấu trúc lưu raw trong repo, và cách tải.

**Tháng mẫu khuyến nghị:** `2024-06` (cả Chicago và NYC; NOAA cùng năm `2024`).

**Kiểm tra URL:** 2026-07-02 (HTTP 200; schema CSV đã lấy mẫu từ file thật).

---

## Mục lục

1. [Tổng quan và cấu trúc thư mục](#1-tổng-quan-và-cấu-trúc-thư-mục)
2. [Dataset 1: Divvy Trip Data (Chicago)](#2-dataset-1-divvy-trip-data-chicago)
3. [Dataset 2: Citi Bike Trip Histories (NYC)](#3-dataset-2-citi-bike-trip-histories-nyc)
4. [Dataset 3: NOAA LCD](#4-dataset-3-noaa-lcd)
5. [Khóa join giữa ba nguồn](#5-khóa-join-giữa-ba-nguồn)
6. [Tải và lưu raw](#6-tải-và-lưu-raw)
7. [Lưu ý Git và dung lượng](#7-lưu-ý-git-và-dung-lượng)

---

## 1. Tổng quan và cấu trúc thư mục

Ba dataset phục vụ vai trò khác nhau trong ETL:


| # | Nguồn | Vai trò DW | Pull/Push | Grain nguồn |
|---|-------|------------|-----------|-------------|
| 1 | Divvy trip ZIP | Giao dịch Chicago | Pull (LSET/CET) | 1 dòng / chuyến |
| 2 | Citi Bike trip ZIP | Giao dịch NYC | Pull (LSET/CET) | 1 dòng / chuyến |
| 3 | NOAA LCD CSV | Thời tiết theo giờ | Pull (LSET/CET) | 1 dòng / quan sát (thường theo giờ) |

GBFS (`station_information`, `station_status`) là master Push, **không** nằm trong ba file bulk này; nhóm có thể bổ sung sau dưới `raw/gbfs/` khi mô phỏng MDM.

### Cây thư mục `datasets/`

```text
4_Official_Hop_Project/datasets/
├── README.md                 # Tài liệu này
├── download_datasets.sh      # Script tải raw (curl)
├── manifest.json             # Sinh sau khi chạy script (metadata, không commit bắt buộc)
└── raw/                      # Dữ liệu gốc — không commit (xem .gitignore)
    ├── divvy/trips/
    │   ├── 202406-divvy-tripdata.zip
    │   └── extracted/202406/           # Tùy chọn sau --extract
    ├── citibike/trips/
    │   ├── 202406-citibike-tripdata.zip
    │   └── extracted/202406/
    └── noaa/lcd/
        └── 2024/
            ├── 72534014819.csv         # Chicago
            └── 72505394728.csv         # NYC
```

Nguyên tắc lưu raw:

- Giữ **đúng tên file** từ nguồn (ZIP/CSV) để audit và `manifest.json`.
- Không chỉnh sửa, không gộp, không đổi encoding trước khi vào Staging Hop.
- ZIP trip: có thể giữ nguyên ZIP; giải nén chỉ khi pipeline Hop đọc file CSV trực tiếp.

---

## 2. Dataset 1: Divvy Trip Data (Chicago)

### 2.1. Bối cảnh

Divvy là hệ thống bike-share của Chicago (Lyft). Nhà vận hành công bố **lịch sử chuyến đi theo tháng** trên S3. Đây là nguồn giao dịch chính cho `city_code = CHI`, drive measure `trips_started`, `trips_ended`, `member_trip_count`, v.v. trên `Fact_StationHourBalance`.

### 2.2. Nguồn tải


| Hạng mục | Giá trị |
|----------|---------|
| Trang chính thức | https://divvybikes.com/system-data |
| Bucket S3 | `https://divvy-tripdata.s3.amazonaws.com/` |
| Pattern file | `{YYYYMM}-divvy-tripdata.zip` |
| Ví dụ tháng mẫu | `https://divvy-tripdata.s3.amazonaws.com/202406-divvy-tripdata.zip` |
| Kích thước (2024-06) | ~28 MB (zip); CSV trong zip ~138 MB |

### 2.3. Cấu trúc file

- Một ZIP chứa **một** CSV: `202406-divvy-tripdata.csv`.
- Encoding: UTF-8; dòng đầu là header; các field text được bọc dấu ngoặc kép.

**Header thực tế (2024-06, đã kiểm tra):**

```text
"ride_id","rideable_type","started_at","ended_at","start_station_name","start_station_id",
"end_station_name","end_station_id","start_lat","start_lng","end_lat","end_lng","member_casual"
```

### 2.4. Phân tích cột


| Cột | Kiểu / ví dụ | ETL / DW |
|-----|--------------|----------|
| `ride_id` | Chuỗi | Khóa nghiệp vụ chuyến; dedup staging |
| `rideable_type` | `electric_bike`, `classic_bike`, … | → `electric_trip_count`, `classic_trip_count` |
| `started_at`, `ended_at` | Timestamp có ms | Cắt về giờ Chicago (`America/Chicago`); LSET/CET incremental |
| `start_station_id`, `end_station_id` | Chuỗi hoặc rỗng | Join `Dim_Station` qua `source_station_id` + `city_sk` |
| `start_station_name`, `end_station_name` | Text; có thể rỗng | DQ; dockless để trống tên/id |
| `start_lat/lng`, `end_lat/lng` | Float | Bổ sung khi thiếu master trạm |
| `member_casual` | `member` / `casual` | Phân rã loại người dùng |

### 2.5. Độ bẩn và thách thức ETL

- **Dockless / round-trip:** `start_station_id` và `end_station_id` rỗng; vẫn có lat/lng.
- **Schema đổi theo năm:** cột cũ (`trip_id`, `gender`, …) khác post-2020; ETL cần map theo năm file.
- **Timezone:** timestamp trong CSV là giờ địa phương Chicago; thống nhất trước khi join NOAA và aggregate fact.
- **Không có tồn kho xe:** file trip không có `num_bikes_available`; KPI mất cân bằng dựa trên dòng chuyến (`net_flow`), không phải inventory.

---

## 3. Dataset 2: Citi Bike Trip Histories (NYC)

### 3.1. Bối cảnh

Citi Bike (NYC) dùng cùng mô hình công bố dữ liệu monthly ZIP trên S3. Grain và semantics tương tự Divvy nhưng **namespace `station_id` khác hoàn toàn**; chỉ so sánh xuyên thành phố qua `Dim_City`.

### 3.2. Nguồn tải


| Hạng mục | Giá trị |
|----------|---------|
| Trang chính thức | https://citibikenyc.com/system-data |
| Bucket S3 | `https://s3.amazonaws.com/tripdata/` |
| Pattern file | `{YYYYMM}-citibike-tripdata.zip` |
| Ví dụ tháng mẫu | `https://s3.amazonaws.com/tripdata/202406-citibike-tripdata.zip` |
| Kích thước (2024-06) | ~936 MB (zip); tổng CSV ~936 MB |

### 3.3. Cấu trúc file

Khác Divvy: một ZIP tháng 2024-06 chứa **năm** CSV tách phần:

```text
202406-citibike-tripdata_1.csv  (~186 MB)
202406-citibike-tripdata_2.csv
202406-citibike-tripdata_3.csv
202406-citibike-tripdata_4.csv
202406-citibike-tripdata_5.csv  (~154 MB)
```

Hop ETL: đọc **tất cả** `*.csv` trong thư mục extracted, hoặc loop unzip từng part.

**Header thực tế (2024-06, file _1, đã kiểm tra):**

```text
ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,
end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual
```

(Lưu ý: không có dấu ngoặc kép quanh tên cột; vẫn là CSV chuẩn.)

### 3.4. Phân tích cột

Cùng semantics với Divvy (xem bảng mục 2.4). Khác biệt kỹ thuật:

- `start_station_id` / `end_station_id` có thể mang dạng **số thập phân** trong file (ví dụ `6233.04`, `5096.12`). Staging nên cast về **text** trước khi join dimension, tránh mất precision.
- Timestamp ví dụ: `2024-06-19 19:02:23.487` (giờ địa phương NYC, `America/New_York`).

### 3.5. Độ bẩn và thách thức ETL

- **Dung lượng lớn:** một tháng ~1 GB; cần đủ disk và thời gian tải (vài phút).
- **Nhiều file trong một ZIP:** pipeline phải union tất cả part trước load staging.
- **Schema lịch sử:** tên cột đổi trước 2019; tháng mẫu 2024-06 đồng bộ với Divvy hiện đại.
- **Không join `station_id` với Divvy:** chỉ union fact sau khi gắn `city_sk`.

---

## 4. Dataset 3: NOAA LCD

### 4.1. Bối cảnh

NOAA NCEI **Local Climatological Data (LCD)** cung cấp quan trắc khí tượng theo trạm, lưu bulk theo **năm**. Mỗi thành phố trong đề tài map một trạm LCD riêng; join fact qua `city_code` + `date_hour`.

### 4.2. Nguồn tải


| Hạng mục | Giá trị |
|----------|---------|
| Bulk access | https://www.ncei.noaa.gov/data/local-climatological-data/access/ |
| Pattern | `.../access/{YEAR}/{STATION_ID}.csv` |
| Chicago | `72534014819.csv` — CHICAGO MIDWAY AIRPORT, IL US (~7.9 MB/năm 2024) |
| New York | `72505394728.csv` — NY CITY CENTRAL PARK, NY US (~8.5 MB/năm 2024) |

URL ví dụ:

- https://www.ncei.noaa.gov/data/local-climatological-data/access/2024/72534014819.csv
- https://www.ncei.noaa.gov/data/local-climatological-data/access/2024/72505394728.csv

### 4.3. Cấu trúc file

- Một CSV **rộng** (~100+ cột): vừa quan sát theo giờ, vừa cột daily/monthly trên cùng dòng.
- Dòng dữ liệu: `STATION`, `DATE` (ISO có timezone offset), nhiều cột `Hourly*`, `Daily*`, `Monthly*`.
- Giá trị thiếu thường là chuỗi rỗng hoặc ký hiệu đặc biệt (`T` = trace cho precip).

**Cột map sang fact (đề tài):**


| Cột LCD | Measure trên fact | Ghi chú |
|---------|-------------------|---------|
| `DATE` | → `datetime_sk` / `date_hour` | Cắt về giờ; timezone trạm |
| `HourlyDryBulbTemperature` | `temperature` | Semi-additive; AVG khi roll-up |
| `HourlyPrecipitation` | `precipitation` | `T` = trace → 0 hoặc NULL theo rule DQ |
| `HourlyWindSpeed` | `wind_speed` | |
| (rule ETL) | `weather_condition_sk` | Bucket Clear/Rain/Snow từ precip + weather type |

### 4.4. Độ bẩn và thách thức ETL

- **Chỉ dùng hàng có quan sát giờ hợp lệ:** lọc `REPORT_TYPE` / dòng có `HourlyDryBulbTemperature` không rỗng khi cần grain giờ.
- **Một file cho cả năm:** incremental LSET/CET theo `DATE` parsed, không theo tháng trip.
- **Trạm sân bay / công viên:** đại diện khí hậu đô thị, không đúng từng block; chấp nhận cho môn học (đã validate trong topic_exploration_v2).
- **Cột daily/monthly lặp trên mỗi dòng giờ:** không đưa vào fact; tránh double-count.

---

## 5. Khóa join giữa ba nguồn


| Cặp | Khóa | Ghi chú |
|-----|------|---------|
| Divvy ↔ Citi Bike | `city_sk` sau ETL | Union fact; **không** join `station_id` |
| Trip ↔ NOAA | `city_code` + `date_hour` local | Chicago ↔ `72534014819`; NYC ↔ `72505394728` |
| Trip ↔ GBFS (sau này) | `city_sk` + `source_station_id` | Trong từng thành phố |

**Cửa sổ thời gian đồng bộ:** trip tháng `2024-06` + NOAA file `2024/*.csv` (lọc row tháng 6 khi load staging nếu chỉ demo một tháng).

---

## 6. Tải và lưu raw

### 6.1. Script tự động (khuyến nghị)

```bash
cd 4_Official_Hop_Project/datasets
chmod +x download_datasets.sh
./download_datasets.sh              # YYYYMM=202406, NOAA năm 2024
./download_datasets.sh 202406 --extract   # thêm giải nén CSV trip
```

Biến môi trường:

```bash
SAMPLE_YEAR=2024 ./download_datasets.sh 202406
```

Sau khi chạy, kiểm tra `manifest.json` (đường dẫn, URL, kích thước byte).

### 6.2. Tải thủ công (curl)

```bash
ROOT="4_Official_Hop_Project/datasets/raw"
YM=202406
YEAR=2024

mkdir -p "$ROOT/divvy/trips" "$ROOT/citibike/trips" "$ROOT/noaa/lcd/$YEAR"

curl -fL -o "$ROOT/divvy/trips/${YM}-divvy-tripdata.zip" \
  "https://divvy-tripdata.s3.amazonaws.com/${YM}-divvy-tripdata.zip"

curl -fL -o "$ROOT/citibike/trips/${YM}-citibike-tripdata.zip" \
  "https://s3.amazonaws.com/tripdata/${YM}-citibike-tripdata.zip"

curl -fL -o "$ROOT/noaa/lcd/${YEAR}/72534014819.csv" \
  "https://www.ncei.noaa.gov/data/local-climatological-data/access/${YEAR}/72534014819.csv"

curl -fL -o "$ROOT/noaa/lcd/${YEAR}/72505394728.csv" \
  "https://www.ncei.noaa.gov/data/local-climatological-data/access/${YEAR}/72505394728.csv"
```

Giải nén trip (tùy chọn):

```bash
unzip -o "$ROOT/divvy/trips/${YM}-divvy-tripdata.zip" \
  -d "$ROOT/divvy/trips/extracted/${YM}"

unzip -o "$ROOT/citibike/trips/${YM}-citibike-tripdata.zip" \
  -d "$ROOT/citibike/trips/extracted/${YM}"
```

### 6.3. Liên kết Hop Staging

Gợi ý biến trong `development_configs.json` (bổ sung sau):


| Biến | Ví dụ |
|------|-------|
| `RAW_DATASET_ROOT` | `${PROJECT_HOME}/datasets/raw` |
| `DIVVY_TRIP_ZIP` | `.../divvy/trips/202406-divvy-tripdata.zip` |
| `CITIBIKE_TRIP_DIR` | `.../citibike/trips/extracted/202406/` |
| `NOAA_LCD_CHICAGO` | `.../noaa/lcd/2024/72534014819.csv` |
| `NOAA_LCD_NYC` | `.../noaa/lcd/2024/72505394728.csv` |

Pipeline Pull đọc từ đường dẫn trên; `control.etl_extraction_control` ghi `lset`/`cet` theo `started_at` (trip) hoặc `DATE` (NOAA).

---

## 7. Lưu ý Git và dung lượng

| Nguồn | Dung lượng ước tính (2024-06 + NOAA 2024) |
|-------|---------------------------------------------|
| Divvy ZIP | ~28 MB |
| Citi Bike ZIP | ~936 MB |
| NOAA (2 file) | ~16 MB |
| **Tổng** | **~980 MB** |

Thư mục `raw/` được **gitignore** (file lớn, tái tải được từ URL). Repo chỉ giữ cấu trúc thư mục, script, và `README.md`. Mỗi thành viên chạy `download_datasets.sh` trên máy local hoặc copy raw qua NAS / drive nhóm.

---

*Tài liệu dataset — HCMUS Master IS, Advanced Business Intelligence. Đối chiếu [official_topic.md](../../0_topic_exploration/official_topic.md).*
