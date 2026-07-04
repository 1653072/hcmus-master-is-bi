# A_datasets — Phân tích và hướng dẫn tải raw

Tài liệu bổ sung [official_topic.md](../../0_topic_exploration/official_topic.md) mục 5: ba nguồn đăng ký (Divvy, Citi Bike, NOAA LCD) + GBFS master (triển khai).

**Kỳ mẫu triển khai:** `2026-01` → `2026-05` (01–05/2026) — trip ZIP theo tháng + NOAA LCD **v2** bulk năm 2026 (lọc 01–05 sau tải).

**Kiểm tra URL:** 2026-07-04 (HTTP 200; schema CSV lấy mẫu từ file NCEI thật).

---

## Mục lục

1. [Tổng quan và cấu trúc thư mục](#1-tổng-quan-và-cấu-trúc-thư-mục)
2. [Dataset A2: Divvy Trip Data (Chicago)](#2-dataset-a2-divvy-trip-data-chicago)
3. [Dataset A1: Citi Bike Trip Histories (NYC)](#3-dataset-a1-citi-bike-trip-histories-nyc)
4. [Dataset A3: NOAA LCD v2](#4-dataset-a3-noaa-lcd-v2)
5. [Dataset A4: GBFS station_information (MDM)](#5-dataset-a4-gbfs-station_information-mdm)
6. [Khóa join giữa các nguồn](#6-khóa-join-giữa-các-nguồn)
7. [Đối chiếu yêu cầu đề bài (PDF / official_topic.md)](#7-đối-chiếu-yêu-cầu-đề-bài-pdf--official_topicmd)
8. [Tải và lưu raw](#8-tải-và-lưu-raw)
9. [Lưu ý Git và dung lượng](#9-lưu-ý-git-và-dung-lượng)

---

## 1. Tổng quan và cấu trúc thư mục

| Thư mục | Nguồn | Vai trò DW | Pull/Push | Grain |
|---------|-------|------------|-----------|-------|
| `A2_divvy/` | Divvy trip ZIP | Giao dich Chicago | Pull (LSET/CET) | 1 dòng / chuyến |
| `A1_citibike/` | Citi Bike trip ZIP | Giao dịch NYC | Pull (LSET/CET) | 1 dòng / chuyến |
| `A3_noaa_lcd_v2/` | NOAA LCD v2 CSV | Thời tiết theo giờ | Pull (LSET/CET) | 1 dòng / quan sát giờ |
| `A4_mdm_station_info/` | GBFS JSON | Master trạm (`Dim_Station`) | Push (MDM) | 1 dòng / trạm |

### Cây thư mục `A_datasets/`

```text
A_datasets/
├── README.md                    # Tài liệu này
├── download_datasets.sh         # Script tải + lọc NOAA 01–05/2026
├── manifest.json                # Sinh sau khi chạy script
├── .gitignore
├── A1_citibike/
│   ├── 202601-citibike-tripdata.zip
│   ├── … 202605-…
│   └── extracted/202601/        # Tùy chọn (--extract)
├── A2_divvy/
│   ├── 202601-divvy-tripdata.zip
│   └── extracted/202601/
├── A3_noaa_lcd_v2/
│   ├── raw/LCD_USW00014819_2026.csv      # Bulk năm (giữ audit)
│   ├── raw/LCD_USW00094728_2026.csv
│   ├── LCD_USW00014819_2026_01-05.csv    # Dùng cho ETL (01–05/2026)
│   └── LCD_USW00094728_2026_01-05.csv
└── A4_mdm_station_info/
    ├── divvy_station_information.json    # Tùy chọn (--gbfs)
    └── citibike_station_information.json
```

Nguyên tắc lưu raw:

- Giữ **đúng tên file** từ nguồn (ZIP/CSV/JSON).
- **Không** sửa nội dung trip ZIP; NOAA bulk năm giữ trong `raw/`, bản **lọc 01–05** do script sinh (chỉ cắt dòng theo `DATE`, không đổi giá trị quan sát).
- Hop ETL đọc file **filtered** NOAA và trip tháng `202601`–`202605`.

---

## 2. Dataset A2: Divvy Trip Data (Chicago)

| Hạng mục | Giá trị |
|----------|---------|
| Trang | https://divvybikes.com/system-data |
| S3 | `https://divvy-tripdata.s3.amazonaws.com/{YYYYMM}-divvy-tripdata.zip` |
| Ví dụ | `202601-divvy-tripdata.zip` … `202605-divvy-tripdata.zip` |
| `city_code` | `CHI` |

**Header (schema hiện đại, đã kiểm tra):**

```text
ride_id, rideable_type, started_at, ended_at, start_station_name, start_station_id,
end_station_name, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual
```

| Cột | DW / ETL |
|-----|----------|
| `started_at`, `ended_at` | Cắt giờ `America/Chicago`; LSET/CET incremental |
| `start/end_station_id` | Join `Dim_Station` qua `source_station_id` + `city_sk` |
| `start/end_lat/lng` | Fallback tọa độ trạm |
| `rideable_type`, `member_casual` | Measure electric/classic, member/casual |

**Lưu ý:** Trip CSV **không** có tồn kho xe; `net_flow` suy từ dòng chuyến (PDF/md).

---

## 3. Dataset A1: Citi Bike Trip Histories (NYC)

| Hạng mục | Giá trị |
|----------|---------|
| Trang | https://citibikenyc.com/system-data |
| S3 | `https://s3.amazonaws.com/tripdata/{YYYYMM}-citibike-tripdata.zip` |
| `city_code` | `NYC` |

Một ZIP tháng có thể chứa **nhiều** CSV part (`_1.csv` … `_5.csv`); ETL union tất cả sau `--extract`.

| Khác Divvy | Xử lý |
|------------|--------|
| `station_id` dạng số thập phân (`6233.04`) | Cast **text** trước join dim |
| Dung lượng lớn (~350–900 MB/tháng) | Đủ disk; tải tuần tự qua script |
| Namespace `station_id` | **Không** join trực tiếp với Divvy |

Timezone trip: `America/New_York`.

---

## 4. Dataset A3: NOAA LCD v2

### 4.1. Vì sao chuyển từ LCD v1 sang v2?

| | LCD v1 | LCD v2 |
|---|--------|--------|
| Trạng thái NCEI | **Deprecated** — ngừng cập nhật **29/08/2025** | Sản phẩm hiện hành ([NCEI LCD](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data)) |
| Nguồn quan sát | ISD (Integrated Surface Dataset) | **GHCN Hourly (GHCNh)** + GHCN Daily |
| Bulk URL | `.../data/local-climatological-data/access/{YEAR}/{725…}.csv` | `.../oa/local-climatological-data/v2/access/{YEAR}/LCD_{GHCND_ID}_{YEAR}.csv` |
| Station ID | WBAN-style `72534014819`, `72505394728` | GHCND `USW00014819`, `USW00094728` |
| Đơn vị | US customary (°F, inch, …) | **Metric / SI** (°C, mm, m/s) |
| Dữ liệu **2026** hourly | **404** (bulk v1) | **Có** (bulk v2, cập nhật liên tục) |

Vẫn thuộc họ **Local Climatological Data (LCD)** — khớp dataset thứ 3 trong [PDF đăng ký](../../0_topic_exploration/official_topic_for_report.pdf); triển khai dùng **v2 bulk** vì v1 không còn phủ 2026.

### 4.2. Trạm map theo thành phố

| Thành phố | `city_code` | LCD v2 `STATION` | Tên | Lat / Lng (file) | LCD v1 (legacy) |
|-----------|-------------|------------------|-----|------------------|-----------------|
| Chicago | `CHI` | `USW00014819` | CHICAGO MIDWAY AP, IL US | 41.7842, -87.7553 | `72534014819` |
| New York | `NYC` | `USW00094728` | NY CITY CENTRAL PARK, NY US | 40.77898, -73.96925 | `72505394728` |

Cùng **địa điểm vật lý** với v1; chỉ đổi mã trạm và đường dẫn bulk.

### 4.3. URL bulk (2026)

| Thành phố | URL |
|-----------|-----|
| Chicago | https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00014819_2026.csv |
| NYC | https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00094728_2026.csv |
| Object Store | https://www.ncei.noaa.gov/oa/local-climatological-data/index.html#v2/access/2026/ |

Pattern: `LCD_{STATION_ID}_{YEAR}.csv`

### 4.4. Cấu trúc file (~125 cột)

- Format: CSV quoted; header giống v1 về **tên cột** chính.
- `DATE`: ISO local `2026-01-01T08:51:00` (giờ quan sát trạm; LST — **không** UTC).
- Một file **cả năm**; mỗi dòng có thể mix cột `Hourly*`, `Daily*`, `Monthly*` (chỉ dùng hourly cho fact grain giờ).

**`REPORT_TYPE` (lọc staging):**

| Giá trị | Ý nghĩa | Dùng cho fact giờ? |
|---------|---------|-------------------|
| `FM-12`, `FM-15`, `FM-16`, … | METAR / quan sát giờ | **Có** — khi có `HourlyDryBulbTemperature` hoặc precip/gió |
| `SOD` | Synoptic Summary of Day (tổng ngày trên 1 dòng) | **Không** — grain ngày |
| `SOM` | Summary of Month | **Không** |

### 4.5. Cột map sang `Fact_StationHourBalance` (đề bài)

| Cột LCD v2 | Measure / FK trên fact | Ghi chú |
|------------|------------------------|---------|
| `DATE` | `datetime_sk` / `date_hour` | Parse → giờ local theo city |
| `HourlyDryBulbTemperature` | `temperature` | **°C** (v2); semi-additive AVG |
| `HourlyPrecipitation` | `precipitation` | **mm**; `T` = trace → 0 hoặc NULL (rule DQ) |
| `HourlyWindSpeed` | `wind_speed` | **m/s** (v2) |
| `HourlyPresentWeatherType` + precip | `weather_condition_sk` | Rule ETL → Clear / Rain / Snow / Fog |
| `LATITUDE`, `LONGITUDE` | Không lên fact | Trạm khí tượng ≠ trạm xe; join qua `city_code` |

**Chuyển đổi đơn vị (tùy dashboard):** ETL có thể giữ metric trên DDS hoặc convert sang °F/inch nếu báo cáo yêu cầu; đề md **không** bắt buộc đơn vị US.

### 4.6. Lọc 01–05/2026 (script)

File bulk năm 2026 có thể chứa tháng 6+ (NCEI cập nhật dần). Script:

1. Tải bulk → `A3_noaa_lcd_v2/raw/`.
2. Sinh `*_01-05.csv`: giữ mọi dòng có `DATE` từ `2026-01-01` đến `2026-05-31`.

Hop Pull / staging đọc file **filtered** để đồng bộ với trip `202601`–`202605`.

### 4.7. Thách thức ETL (v2)

- **Đơn vị metric** — ghi rõ trong metadata staging nếu so sánh với tài liệu cũ viết theo v1.
- **Nhiều dòng / giờ** — một số giờ có >1 quan sát; dedup theo `(STATION, date_hour)` (ưu tiên `FM-15`/`FM-16` hoặc dòng có đủ 3 measure).
- **Giá trị rỗng** — precip/wind có thể blank; không coi là 0 trừ khi rule DQ quy định.
- **Trạm đại diện đô thị** — sân bay / công viên; chấp nhận cho môn học (đã validate topic_exploration_v2).

### 4.8. So sánh nhanh v1 vs v2 (mẫu NYC, cùng logic)

| | v1 (2025) | v2 (2026) |
|---|-----------|-----------|
| Nhiệt độ mẫu tháng 1 | ~46 °F | ~0.6 °C |
| Station column | `72505394728` | `USW00094728` |
| Join key với trip | `city_code` + `date_hour` | **Giữ nguyên** |

---

## 5. Dataset A4: GBFS station_information (MDM)

| Hạng mục | Giá trị |
|----------|---------|
| Vai trò | Push MDM → `Dim_Station` (SCD2); **không** trong bảng 3 dataset PDF |
| Divvy | https://gbfs.lyft.com/gbfs/2.3/chi/en/station_information.json |
| Citi Bike | https://gbfs.citibikenyc.com/gbfs/en/station_information.json |
| Khóa | `city_sk` + `source_station_id` |

Tải bằng `./download_datasets.sh --gbfs`.

---

## 6. Khóa join giữa các nguồn

| Cặp | Khóa | Ghi chú |
|-----|------|---------|
| Divvy ↔ Citi Bike | `city_sk` | Union fact; không join `station_id` |
| Trip ↔ NOAA v2 | `city_code` + `date_hour` local | CHI ↔ `USW00014819`; NYC ↔ `USW00094728` |
| Trip ↔ GBFS | `city_sk` + `source_station_id` | Trong từng thành phố |

**Cửa sổ đồng bộ:** trip `202601`–`202605` + NOAA filtered `*_01-05.csv` (cùng năm 2026, không proxy).

---

## 7. Đối chiếu yêu cầu đề bài (PDF / official_topic.md)

| Yêu cầu đề bài | LCD v2 + trip 01–05/2026 |
|----------------|--------------------------|
| Dataset 3: NOAA NCEI **Local Climatological Data** | **Đáp ứng** (v2 cùng sản phẩm LCD, trạm tương đương v1) |
| Pull theo giờ: `HourlyDryBulbTemperature`, `HourlyPrecipitation`, `HourlyWindSpeed` | **Có** trên cột cùng tên |
| Join `city_code` + `date_hour` | **Có** — timezone trip city ↔ `DATE` trạm |
| Fact grain City × Station × Hour | Trip aggregate + weather denormalize theo giờ |
| `Dim_WeatherCondition` (Clear/Rain/Snow) | Rule ETL từ precip + `HourlyPresentWeatherType` |
| Phân tích tuần / cuối tuần (`is_weekend`) | `Dim_DateTime` từ lịch **2026**; weather **2026 thật** (không proxy 2025) |
| KPI `Weather_Sensitivity_Score`, mưa/nắng × giờ | **Hợp lệ** với dữ liệu quan sát thật |
| Chicago + NYC so sánh công bằng | Cùng kỳ 5 tháng 2026 |

---

## 8. Tải và lưu raw

### 8.1. Script (khuyến nghị)

```bash
cd 4_Official_Hop_Project/A_datasets
chmod +x download_datasets.sh

./download_datasets.sh --urls-only          # validate HTTP
./download_datasets.sh                        # tải trip 202601–202605 + NOAA v2 + lọc 01–05
./download_datasets.sh --extract              # thêm giải nén trip CSV
./download_datasets.sh --gbfs                 # thêm GBFS station_information
```

Tuỳ chọn khoảng tháng:

```bash
./download_datasets.sh --from 202603 --to 202604
```

### 8.2. Biến Hop (`development_configs.json` — bổ sung khi có pipeline)

| Biến | Ví dụ |
|------|-------|
| `RAW_DATASET_ROOT` | `${PROJECT_HOME}/A_datasets` |
| `SAMPLE_PERIOD` | `202601-202605` |
| `NOAA_LCD_CHICAGO` | `.../A3_noaa_lcd_v2/LCD_USW00014819_2026_01-05.csv` |
| `NOAA_LCD_NYC` | `.../A3_noaa_lcd_v2/LCD_USW00094728_2026_01-05.csv` |
| `DIVVY_TRIP_GLOB` | `.../A2_divvy/20260{1,2,3,4,5}-divvy-tripdata.zip` |
| `CITIBIKE_TRIP_DIR` | `.../A1_citibike/extracted/` |

---

## 9. Lưu ý Git và dung lượng

| Nguồn | Ước tính (01–05/2026) |
|-------|------------------------|
| Divvy ZIP (5 tháng) | ~70 MB |
| Citi Bike ZIP (5 tháng) | ~2.2 GB |
| NOAA v2 filtered (2 file) | ~6–7 MB |
| **Tổng** | **~2.3 GB** |

File lớn **gitignore**; mỗi thành viên chạy `download_datasets.sh` local.

---

*Tài liệu dataset — HCMUS Master IS, Advanced BI. Đối chiếu [official_topic.md](../../0_topic_exploration/official_topic.md) và [README.md](../README.md).*
