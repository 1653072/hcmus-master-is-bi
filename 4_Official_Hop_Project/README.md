# 4_Official_Hop_Project — Bike-share DW (Hop ETL)

Dự án Apache Hop chính thức cho đề tài **Xây dựng Data Warehouse phân tích dữ liệu để lập kế hoạch điều phối hệ thống xe đạp công cộng tại Chicago và New York**.

**Đối chiếu đề bài:** [official_topic.md](../0_topic_exploration/official_topic.md) · [PDF đăng ký](../0_topic_exploration/official_topic_for_report.pdf)

**Kỳ dữ liệu triển khai:** **01–05/2026** (Divvy, Citi Bike, NOAA LCD v2).

**Kiểm tra URL dataset:** 2026-07-04 (HTTP 200; schema CSV lấy mẫu từ file NCEI thật).

---

## Mục lục

1. [Cấu trúc thư mục](#1-cấu-trúc-thư-mục)
2. [Luồng dữ liệu tóm tắt](#2-luồng-dữ-liệu-tóm-tắt)
3. [Bắt đầu nhanh — tải dữ liệu](#3-bắt-đầu-nhanh--tải-dữ-liệu)
4. [Thành phần theo thư mục](#4-thành-phần-theo-thư-mục)
5. [Cấu hình Hop](#5-cấu-hình-hop)
6. [Trạng thái triển khai](#6-trạng-thái-triển-khai)
7. [A_datasets — Phân tích và hướng dẫn tải](#7-a_datasets--phân-tích-và-hướng-dẫn-tải)
  - [7.1 Tổng quan và cấu trúc](#71-tổng-quan-và-cấu-trúc-a_datasets)
  - [7.2 Divvy (Chicago)](#72-dataset-a2-divvy-trip-data-chicago)
  - [7.3 Citi Bike (NYC)](#73-dataset-a1-citi-bike-trip-histories-nyc)
  - [7.4 NOAA LCD v2](#74-dataset-a3-noaa-lcd-v2)
  - [7.5 GBFS station_information](#75-dataset-a4-gbfs-station_information-mdm)
  - [7.6 Khóa join](#76-khóa-join-giữa-các-nguồn)
  - [7.7 Đối chiếu đề bài](#77-đối-chiếu-yêu-cầu-đề-bài-pdf--official_topicmd)
  - [7.8 Tải và lưu file](#78-tải-và-lưu-file)
  - [7.9 Git và dung lượng](#79-lưu-ý-git-và-dung-lượng)

---



## 1. Cấu trúc thư mục

```text
4_Official_Hop_Project/
├── README.md                      # Tài liệu này (master doc — bổ sung dần)
├── Makefile                       # Lệnh nhanh: make datasets-full, make help, …
├── development_configs.json       # Biến môi trường Hop
├── project-config.json            # Hop project config
│
├── A_datasets/                    # Trip + NOAA + GBFS (mục 7)
│   ├── download_datasets.sh
│   ├── manifest.json
│   ├── A1_citibike/
│   ├── A2_divvy/
│   ├── A3_noaa_lcd_v2/
│   └── A4_mdm_station_info/
│
├── B_databases/                   # Docker PostgreSQL (STG / NDS / DDS)
│   ├── docker-compose.yml
│   ├── B1_dw_stg_postgresql/
│   ├── B2_dw_nds_postgresql/
│   └── B3_dw_dds_postgresql/
│
├── C_backend/                     # MDM Push (Go)
│   └── C1_mdm_station_info/
│       ├── go.mod
│       ├── main.go
│       └── push_mdm_station_info.go
│
├── D_pipelines/                   # Hop pipelines (.hpl) — nhóm tạo
├── E_workflows/                   # Hop workflows (.hwf) — nhóm tạo
└── metadata/                      # Hop DB connection metadata
```

---



## 2. Luồng dữ liệu tóm tắt

```text
[A4 GBFS Push]  ──► Staging ──► NDS (station) ──► DDS Dim_Station (SCD2)
[A2 Divvy Pull]  ──┐
[A1 Citi Pull]   ──┼──► Staging ──► NDS (trip) ──► aggregate ──► Fact_StationHourBalance
[A3 NOAA Pull]   ──┘         ▲
                               └── join city_code + date_hour (LCD v2 hourly)
```

- **Fact:** `Fact_StationHourBalance` — grain City × Station × Hour (Periodic Snapshot).
- **Pull Staging:** 00:00 GMT+7 (17:00 UTC), LSET/CET theo `official_topic.md`.
- **NOAA:** LCD V2 bulk 2026; ETL dùng file lọc `*_01-05.csv` (metric °C, mm, m/s).

Chi tiết từng nguồn: [mục 7](#7-a_datasets--phân-tích-và-hướng-dẫn-tải).

---



## 3. Bắt đầu nhanh — tải dữ liệu

**Windows (CMD / PowerShell / Git Bash):**

1. Cài [Git for Windows](https://git-scm.com/download/win) (có `bash`, `curl`, thường kèm `unzip`).
2. Cài **Python 3.8+** từ [python.org](https://www.python.org/downloads/) — tick **Add python.exe to PATH**. Kiểm tra: `py -3 --version` hoặc `python --version`.
3. Cài **make** (Chocolatey: `choco install make`) nếu dùng `make datasets-full`.

**Lỗi thường gặp trên CMD:**

| Lỗi | Cách xử lý |
|-----|------------|
| `WSL execvpe(/bin/bash) failed` | Cài Git for Windows; tắt alias `bash.exe` trong Settings → App execution aliases; hoặc mở **Git Bash** |
| `curl: (3) URL rejected: Malformed input` | Pull bản mới (script đã strip `\r`); hoặc trong Git Bash: `sed -i 's/\r$//' A_datasets/download_datasets.sh` rồi chạy lại |
| `Python was not found` / `Microsoft Store` | Cài [Python 3](https://www.python.org/downloads/) (tick **Add to PATH**); tắt alias `python.exe` / `python3.exe` trong App execution aliases; thử `py -3 --version` |

**Makefile** (chạy từ `4_Official_Hop_Project/`):

```bash
cd 4_Official_Hop_Project

make help                 # danh sách target
make datasets-check       # validate HTTP URL
make datasets-full        # full pack 01–05/2026: trip + NOAA + extract + GBFS
make datasets-status      # manifest + dung lượng từng folder
```

**Windows (không có `make`):** mở **Git Bash** trong thư mục project:

```bash
bash A_datasets/download_datasets.sh --urls-only
bash A_datasets/download_datasets.sh --extract --gbfs
```

Một tháng demo (nhẹ hơn ~2.3 GB):

```bash
make datasets-download FROM=202601 TO=202601
```

**Hoặc script trực tiếp** (macOS/Linux/Git Bash — luôn gọi qua `bash`, không cần `chmod`):

```bash
cd A_datasets

bash download_datasets.sh --urls-only          # validate HTTP
bash download_datasets.sh --extract --gbfs     # tải đủ 01–05/2026 (~2.3 GB ZIP; + disk nếu extract)
```

Sau khi chạy, kiểm tra `A_datasets/manifest.json`. Tùy chọn và biến Hop: [mục 7.8](#78-tải-và-lưu-file).

---



## 4. Thành phần theo thư mục


| Thư mục         | Trạng thái        | Mô tả                                                                                             |
| --------------- | ----------------- | ------------------------------------------------------------------------------------------------- |
| **A_datasets**  | Sẵn sàng          | Script + tài liệu LCD V2, trip 202601–202605 ([mục 7](#7-a_datasets--phân-tích-và-hướng-dẫn-tải)) |
| **B_databases** | Khung placeholder | Docker Compose + init SQL (TODO)                                                                  |
| **C_backend**   | Khung placeholder | Go MDM push GBFS → Hop API (TODO)                                                                 |
| **D_pipelines** | TODO              | Pull staging, NDS, DDS load                                                                       |
| **E_workflows** | TODO              | Orchestration hàng ngày                                                                           |
| **metadata**    | TODO              | Connection STG / NDS / DDS                                                                        |


---



## 5. Cấu hình Hop


| File                       | Vai trò                                                   |
| -------------------------- | --------------------------------------------------------- |
| `project-config.json`      | `dataSetsCsvFolder` → `${PROJECT_HOME}/A_datasets`        |
| `development_configs.json` | Biến DB / API (template từ demo — cập nhật khi có Docker) |
| `metadata/`                | File `.json` kết nối Hop tới PostgreSQL                   |


Mở project trong Hop GUI: trỏ **Project home** tới thư mục `4_Official_Hop_Project`.

---



## 6. Trạng thái triển khai


| Hạng mục                               | Ghi chú                                                         |
| -------------------------------------- | --------------------------------------------------------------- |
| Ba dataset PDF (Divvy, Citi, NOAA LCD) | Trip + NOAA v2 **2026-01 - 2026-05** qua `download_datasets.sh` |
| NOAA LCD v1 → v2                       | V1 deprecated.V2 giữ cùng cột hourly cho Fact table.           |
| GBFS                                   | Tùy chọn `--gbfs`; phục vụ `Dim_Station` Push                   |
| Hop ETL end-to-end                     | Chưa implement — `D_pipelines/`, `E_workflows/`                 |


---



## 7. A_datasets — Phân tích và hướng dẫn tải

Bổ sung [official_topic.md](../0_topic_exploration/official_topic.md) mục 5: ba nguồn đăng ký (Divvy, Citi Bike, NOAA LCD) + GBFS master (triển khai).

**Kỳ mẫu:** `2026-01` → `2026-05` — trip ZIP theo tháng + NOAA LCD V2 bulk năm 2026 (lọc 01–05 sau tải).

### 7.1. Tổng quan và cấu trúc A_datasets


| Thư mục                | Nguồn              | Vai trò DW                  | Pull/Push       | Grain                 |
| ---------------------- | ------------------ | --------------------------- | --------------- | --------------------- |
| `A1_citibike/`         | Citi Bike trip ZIP | Giao dịch NYC               | Pull (LSET/CET) | 1 dòng / chuyến       |
| `A2_divvy/`            | Divvy trip ZIP     | Giao dịch Chicago           | Pull (LSET/CET) | 1 dòng / chuyến       |
| `A3_noaa_lcd_v2/`      | NOAA LCD v2 CSV    | Thời tiết theo giờ          | Pull (LSET/CET) | 1 dòng / quan sát giờ |
| `A4_mdm_station_info/` | GBFS JSON          | Master trạm (`Dim_Station`) | Push (MDM)      | 1 dòng / trạm         |


```text
A_datasets/
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
│   ├── LCD_USW00014819_2026.csv           # Bulk năm (audit)
│   ├── LCD_USW00014819_2026_01-05.csv     # Dùng cho ETL
│   ├── LCD_USW00094728_2026.csv
│   └── LCD_USW00094728_2026_01-05.csv
└── A4_mdm_station_info/
    ├── divvy_station_information.json     # Tùy chọn (--gbfs)
    └── citibike_station_information.json
```

Nguyên tắc lưu file:

- Giữ **đúng tên file** từ nguồn (ZIP/CSV/JSON).
- **Không** có thư mục `raw/` — mỗi dataset nằm trực tiếp trong `A1_`* … `A4_`*.
- NOAA bulk năm và bản lọc 01–05 cùng thư mục `A3_noaa_lcd_v2/`; Hop ETL đọc file `*_01-05.csv`.



### 7.2. Dataset A2: Divvy Trip Data (Chicago)


| Hạng mục    | Giá trị                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| Trang       | [https://divvybikes.com/system-data](https://divvybikes.com/system-data) |
| S3          | `https://divvy-tripdata.s3.amazonaws.com/{YYYYMM}-divvy-tripdata.zip`    |
| Ví dụ       | `202601-divvy-tripdata.zip` … `202605-divvy-tripdata.zip`                |
| `city_code` | `CHI`                                                                    |


**Header (schema hiện đại, đã kiểm tra):**

```text
ride_id, rideable_type, started_at, ended_at, start_station_name, start_station_id,
end_station_name, end_station_id, start_lat, start_lng, end_lat, end_lng, member_casual
```


| Cột                              | DW / ETL                                               |
| -------------------------------- | ------------------------------------------------------ |
| `started_at`, `ended_at`         | Cắt giờ `America/Chicago`; LSET/CET incremental        |
| `start/end_station_id`           | Join `Dim_Station` qua `source_station_id` + `city_sk` |
| `start/end_lat/lng`              | Fallback tọa độ trạm                                   |
| `rideable_type`, `member_casual` | Measure electric/classic, member/casual                |


**Lưu ý:** Trip CSV **không** có tồn kho xe; `net_flow` suy từ dòng chuyến (PDF/md).

### 7.3. Dataset A1: Citi Bike Trip Histories (NYC)


| Hạng mục    | Giá trị                                                                    |
| ----------- | -------------------------------------------------------------------------- |
| Trang       | [https://citibikenyc.com/system-data](https://citibikenyc.com/system-data) |
| S3          | `https://s3.amazonaws.com/tripdata/{YYYYMM}-citibike-tripdata.zip`         |
| `city_code` | `NYC`                                                                      |


Một ZIP tháng có thể chứa **nhiều** CSV part (`_1.csv` … `_5.csv`); ETL union tất cả sau `--extract`.


| Khác Divvy                                 | Xử lý                              |
| ------------------------------------------ | ---------------------------------- |
| `station_id` dạng số thập phân (`6233.04`) | Cast **text** trước join dim       |
| Dung lượng lớn (~350–900 MB/tháng)         | Đủ disk; tải tuần tự qua script    |
| Namespace `station_id`                     | **Không** join trực tiếp với Divvy |


Timezone trip: `America/New_York`.

### 7.4. Dataset A3: NOAA LCD v2



#### 7.4.1. Vì sao chuyển từ LCD v1 sang v2?


|                         | LCD v1                                                        | LCD v2                                                                                                           |
| ----------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Trạng thái NCEI         | **Deprecated** — ngừng cập nhật **29/08/2025**                | Sản phẩm hiện hành ([NCEI LCD](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data)) |
| Nguồn quan sát          | ISD (Integrated Surface Dataset)                              | **GHCN Hourly (GHCNh)** + GHCN Daily                                                                             |
| Bulk URL                | `.../data/local-climatological-data/access/{YEAR}/{725…}.csv` | `.../oa/local-climatological-data/v2/access/{YEAR}/LCD_{GHCND_ID}_{YEAR}.csv`                                    |
| Station ID              | WBAN-style `72534014819`, `72505394728`                       | GHCND `USW00014819`, `USW00094728`                                                                               |
| Đơn vị                  | US customary (°F, inch, …)                                    | **Metric / SI** (°C, mm, m/s)                                                                                    |
| Dữ liệu **2026** hourly | **404** (bulk v1)                                             | **Có** (bulk v2, cập nhật liên tục)                                                                              |


Vẫn thuộc họ **Local Climatological Data (LCD)** — khớp dataset thứ 3 trong [PDF đăng ký](../0_topic_exploration/official_topic_for_report.pdf). Do đó, triển khai dùng **v2 bulk** vì v1 không còn phủ 2026.

#### 7.4.2. Trạm map theo thành phố


| Thành phố | `city_code` | LCD v2 `STATION` | Tên                         | Lat / Lng (file)    | LCD v1 (legacy) |
| --------- | ----------- | ---------------- | --------------------------- | ------------------- | --------------- |
| Chicago   | `CHI`       | `USW00014819`    | CHICAGO MIDWAY AP, IL US    | 41.7842, -87.7553   | `72534014819`   |
| New York  | `NYC`       | `USW00094728`    | NY CITY CENTRAL PARK, NY US | 40.77898, -73.96925 | `72505394728`   |




#### 7.4.3. URL bulk (2026)


| Thành phố    | URL                                                                                                                                                                                              |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Chicago      | [https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00014819_2026.csv](https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00014819_2026.csv) |
| NYC          | [https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00094728_2026.csv](https://www.ncei.noaa.gov/oa/local-climatological-data/v2/access/2026/LCD_USW00094728_2026.csv) |
| Object Store | [https://www.ncei.noaa.gov/oa/local-climatological-data/index.html#v2/access/2026/](https://www.ncei.noaa.gov/oa/local-climatological-data/index.html#v2/access/2026/)                           |


Pattern: `LCD_{STATION_ID}_{YEAR}.csv`

#### 7.4.4. Cấu trúc file (~125 cột)

- Format: CSV quoted; header giống v1 về **tên cột** chính.
- `DATE`: ISO local `2026-01-01T08:51:00` (giờ quan sát trạm; LST — **không** UTC).
- Một file **cả năm**; mỗi dòng có thể mix cột `Hourly`*, `Daily`*, `Monthly*` (chỉ dùng hourly cho fact grain giờ).

`**REPORT_TYPE` (lọc staging):**


| Giá trị                      | Ý nghĩa                 | Dùng cho fact giờ?                                         |
| ---------------------------- | ----------------------- | ---------------------------------------------------------- |
| `FM-12`, `FM-15`, `FM-16`, … | METAR / quan sát giờ    | **Có** — khi có `HourlyDryBulbTemperature` hoặc precip/gió |
| `SOD`                        | Synoptic Summary of Day | **Không** — grain ngày                                     |
| `SOM`                        | Summary of Month        | **Không**                                                  |




#### 7.4.5. Cột map sang `Fact_StationHourBalance`


| Cột LCD v2                          | Measure / FK trên fact      | Ghi chú                                     |
| ----------------------------------- | --------------------------- | ------------------------------------------- |
| `DATE`                              | `datetime_sk` / `date_hour` | Parse → giờ local theo city                 |
| `HourlyDryBulbTemperature`          | `temperature`               | **°C** (v2); semi-additive AVG              |
| `HourlyPrecipitation`               | `precipitation`             | **mm**; `T` = trace → 0 hoặc NULL (rule DQ) |
| `HourlyWindSpeed`                   | `wind_speed`                | **m/s** (v2)                                |
| `HourlyPresentWeatherType` + precip | `weather_condition_sk`      | Rule ETL → Clear / Rain / Snow / Fog        |
| `LATITUDE`, `LONGITUDE`             | Không lên fact              | Join qua `city_code`                        |




#### 7.4.6. Lọc 01–05/2026 (script)

1. Tải bulk → `A3_noaa_lcd_v2/LCD_*_2026.csv`.
2. Sinh `*_01-05.csv`: giữ mọi dòng có `DATE` từ `2026-01-01` đến `2026-05-31`.

Hop Pull / staging đọc file **filtered** để đồng bộ với trip `202601`–`202605`.

#### 7.4.7. Thách thức ETL (v2)

- **Đơn vị metric** — ghi rõ trong metadata staging nếu so sánh với tài liệu cũ viết theo v1.
- **Nhiều dòng / giờ** — dedup theo `(STATION, date_hour)` (ưu tiên `FM-15`/`FM-16`).
- **Giá trị rỗng** — precip/wind có thể blank; không coi là 0 trừ khi rule DQ quy định.
- **Trạm đại diện đô thị** — sân bay / công viên; chấp nhận cho môn học.



#### 7.4.8. So sánh nhanh v1 vs v2 (NYC)


|                      | v1 (2025)                 | v2 (2026)      |
| -------------------- | ------------------------- | -------------- |
| Nhiệt độ mẫu tháng 1 | ~46 °F                    | ~0.6 °C        |
| Station column       | `72505394728`             | `USW00094728`  |
| Join key với trip    | `city_code` + `date_hour` | **Giữ nguyên** |




### 7.5. Dataset A4: GBFS station_information (MDM)


| Hạng mục  | Giá trị                                                                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Vai trò   | Push MDM → `Dim_Station` (SCD2); **không** trong bảng 3 dataset PDF                                                              |
| Divvy     | [https://gbfs.lyft.com/gbfs/2.3/chi/en/station_information.json](https://gbfs.lyft.com/gbfs/2.3/chi/en/station_information.json) |
| Citi Bike | [https://gbfs.citibikenyc.com/gbfs/en/station_information.json](https://gbfs.citibikenyc.com/gbfs/en/station_information.json)   |
| Khóa      | `city_sk` + `source_station_id`                                                                                                  |


Tải bằng `./download_datasets.sh --gbfs`.

### 7.6. Khóa join giữa các nguồn


| Cặp               | Khóa                            | Ghi chú                                  |
| ----------------- | ------------------------------- | ---------------------------------------- |
| Divvy ↔ Citi Bike | `city_sk`                       | Union fact; không join `station_id`      |
| Trip ↔ NOAA v2    | `city_code` + `date_hour` local | CHI ↔ `USW00014819`; NYC ↔ `USW00094728` |
| Trip ↔ GBFS       | `city_sk` + `source_station_id` | Trong từng thành phố                     |


**Cửa sổ đồng bộ:** trip `202601`–`202605` + NOAA filtered `*_01-05.csv` (cùng năm 2026).

### 7.7. Đối chiếu yêu cầu đề bài (PDF / official_topic.md)


| Yêu cầu đề bài                                                                      | LCD v2 + trip 01–05/2026                        |
| ----------------------------------------------------------------------------------- | ----------------------------------------------- |
| Dataset 3: NOAA NCEI **Local Climatological Data**                                  | **Đáp ứng** (v2 cùng sản phẩm LCD)              |
| Pull theo giờ: `HourlyDryBulbTemperature`, `HourlyPrecipitation`, `HourlyWindSpeed` | **Có**                                          |
| Join `city_code` + `date_hour`                                                      | **Có**                                          |
| Fact grain City × Station × Hour                                                    | Trip aggregate + weather denormalize theo giờ   |
| `Dim_WeatherCondition` (Clear/Rain/Snow)                                            | Rule ETL từ precip + `HourlyPresentWeatherType` |
| Phân tích tuần / cuối tuần (`is_weekend`)                                           | Lịch **2026**; weather **2026 thật**            |
| KPI `Weather_Sensitivity_Score`                                                     | **Hợp lệ** với quan sát thật                    |
| Chicago + NYC so sánh công bằng                                                     | Cùng kỳ 5 tháng 2026                            |




### 7.8. Tải và lưu file

**Makefile** (từ `4_Official_Hop_Project/`):

```bash
make datasets-check
make datasets-download              # trip + NOAA, không extract
make datasets-full                  # trip + NOAA + --extract + --gbfs
make datasets-noaa
make datasets-status
make datasets-download FROM=202603 TO=202604
```

**Script (**`A_datasets/download_datasets.sh`**):**

```bash
cd 4_Official_Hop_Project/A_datasets

bash download_datasets.sh --urls-only          # validate HTTP
bash download_datasets.sh                        # tải trip 202601–202605 + NOAA v2 + lọc 01–05
bash download_datasets.sh --extract              # thêm giải nén trip CSV
bash download_datasets.sh --gbfs                 # thêm GBFS station_information
bash download_datasets.sh --noaa-only            # chỉ NOAA
bash download_datasets.sh --from 202603 --to 202604
```

**Biến Hop** (`development_configs.json` — bổ sung khi có pipeline):


| Biến                | Ví dụ                                               |
| ------------------- | --------------------------------------------------- |
| `RAW_DATASET_ROOT`  | `${PROJECT_HOME}/A_datasets`                        |
| `SAMPLE_PERIOD`     | `202601-202605`                                     |
| `NOAA_LCD_CHICAGO`  | `.../A3_noaa_lcd_v2/LCD_USW00014819_2026_01-05.csv` |
| `NOAA_LCD_NYC`      | `.../A3_noaa_lcd_v2/LCD_USW00094728_2026_01-05.csv` |
| `DIVVY_TRIP_GLOB`   | `.../A2_divvy/20260{1,2,3,4,5}-divvy-tripdata.zip`  |
| `CITIBIKE_TRIP_DIR` | `.../A1_citibike/extracted/`                        |




### 7.9. Lưu ý Git và dung lượng


| Nguồn                     | Ước tính (01–05/2026) |
| ------------------------- | --------------------- |
| Divvy ZIP (5 tháng)       | ~70 MB                |
| Citi Bike ZIP (5 tháng)   | ~2.2 GB               |
| NOAA v2 filtered (2 file) | ~6–7 MB               |
| **Tổng**                  | **~2.3 GB**           |


File lớn **gitignore**; mỗi thành viên chạy `download_datasets.sh` local.

---

*HCMUS Master IS — Advanced Business Intelligence — Nhóm 8.*