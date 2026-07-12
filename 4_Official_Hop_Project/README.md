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
8. [Schema DW — Staging, NDS, DDS](#8-schema-dw--staging-nds-dds)
  - [8.1 Tổng quan 3 tầng](#81-tổng-quan-3-tầng)
  - [8.1b Khóa join & GBFS mapping](#81b-khóa-join--gbfs-mapping)
  - [8.2 Staging ER](#82-staging-er-4-bảng)
  - [8.3 Control](#83-control)
  - [8.4 NDS 3NF](#84-nds-3nf-5-bảng)
  - [8.5 DDS Snowflake](#85-dds-snowflake-4-dim--1-fact)
  - [8.6 Seed data](#86-seed-data-ddl)
  - [8.7 Khởi chạy PostgreSQL](#87-khởi-chạy-postgresql-local)
  - [8.8 Hop metadata & biến môi trường](#88-hop-metadata--biến-môi-trường)
  - [8.9 Enum / coded fields](#89-enum--coded-fields)
9. [Push MDM Station](#9-push-mdm-station)

---



## 1. Cấu trúc thư mục

```text
4_Official_Hop_Project/
├── README.md                      # Tài liệu này (master doc — bổ sung dần)
├── Makefile                       # Lệnh nhanh: make datasets-full, make db-up, …
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
│       └── main.go
│
├── D_pipelines/
│   ├── 00_ETL_Push_Station_MDM_To_StagingDB/   # Hop Web Service handlers (mdm-station)
│   ├── 01_ETL_Source_To_StagingDB/
│   ├── 02_ETL_StagingDB_To_NDS/
│   └── 03_ETL_NDS_To_DDS/
│
├── scripts/
│   ├── setup_project_home.sh
│   ├── start_mdm_station_services.sh
│   └── …
│
├── E_workflows/                   # Hop workflows (.hwf) — nhóm tạo
└── metadata/                      # Hop DB + Web Service metadata
    ├── rdbms/                     # dw-staging, dw-control, dw-nds, dw-dds
    ├── web-service/               # mdm-station.json
    ├── pipeline-run-configuration/
    └── workflow-run-configuration/
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

### 2.1 Pipeline 1: Source Files → StagingDB

Lát cắt ETL đầu tiên triển khai trong `D_pipelines/01_ETL_Source_To_StagingDB/` và `E_workflows/01_etl_source_to_stagingdb.hwf`: đây là nhóm pipeline logic cho luồng source files → raw 0NF → DQ validation → accepted staging → audit. Bên trong folder có thể có nhiều Hop `.hpl` step pipelines; `A_datasets/` vẫn là operational landing layer cho JSON/CSV files, Hop đọc file nguồn, chuẩn hóa kiểu dữ liệu, làm sạch giá trị rỗng/trace precipitation, derive `source_city_code`, `trip_month`, rồi upsert vào `dw_staging.staging.*`.

**Nguyên tắc staging cho lát cắt này:**

- CSV trip: đọc recursive `A2_divvy/extracted/{YYYYMM}/*.csv` và `A1_citibike/extracted/{YYYYMM}/*.csv`; giữ `station_id` dạng `TEXT` để không mất mã NYC như `6602.05` hoặc mã CHI như `CHI02042`.
- NOAA LCD v2: đọc hai file `NOAA_LCD_CHICAGO` và `NOAA_LCD_NYC`; chỉ giữ hourly `REPORT_TYPE` dạng `FM-*`, loại daily/monthly summary như `SOD`.
- GBFS JSON: parse `data.stations[*]`, dùng `short_name` làm khóa trạm nghiệp vụ; nếu nguồn thiếu `short_name` thì fallback bằng `gbfs_station_id` để không mất master row, nhưng các dòng fallback này cần được xem là dữ liệu cần review khi join với trip.
- Staging không dùng `batch_id`; audit qua `loaded_at`, `control.etl_extraction_control`, và `control.etl_job_log`. Vì `dw_staging` và `dw_control` là hai database riêng, workflow chạy pipeline `05_audit_staging_load_counts.hpl` sau các load để đọc count từ staging rồi ghi status/count sang control DB.
- Upsert bằng Hop `InsertUpdate` theo business key staging để workflow chạy lại không nhân đôi dữ liệu. Riêng Citi Bike dùng nhánh accepted-row set-based trong PostgreSQL (`INSERT ... ON CONFLICT ... DO UPDATE`) vì dữ liệu lớn; DQ detail/summary vẫn là Hop-visible cross-DB streams.

### 2.2 Pipeline 2: StagingDB → NDS

Luồng chính hiện là Hop workflow nhìn thấy được trong GUI, không phải shell blackbox. `E_workflows/01_etl_source_to_stagingdb.hwf` gọi tuần tự các `.hpl` source load, raw/DQ validation, DQ audit và staging audit. `E_workflows/02_etl_stagingdb_to_nds.hwf` gọi tuần tự các `.hpl` StagingDB → NDS, audit, rồi cleanup staging:

- `D_pipelines/02_ETL_StagingDB_To_NDS/00_start_etl_stagingdb_to_nds.hpl`: set biến `ETL_STAGINGDB_TO_NDS_STARTED_AT` cho audit log
- `D_pipelines/02_ETL_StagingDB_To_NDS/00_check_staging_dq_before_nds.hpl`: chặn NDS/cleanup nếu một source-to-staging result không `SUCCESS`; `DQ_PARTIAL_PASSED` vẫn load accepted rows
- `D_pipelines/02_ETL_StagingDB_To_NDS/01_load_city_calendar_to_nds.hpl`: city code xuất hiện trong staging → `nds.city`; khoảng ngày staging trip/weather → `nds.calendar_day`
- `D_pipelines/02_ETL_StagingDB_To_NDS/01_load_gbfs_station_to_nds.hpl`: `stg_gbfs_station` → `nds.station`
- `D_pipelines/02_ETL_StagingDB_To_NDS/02_load_weather_to_nds.hpl`: `stg_weather` → `nds.weather`, derive `weather_category`
- `D_pipelines/02_ETL_StagingDB_To_NDS/03_prepare_trip_buffer.hpl`: truncate transient `import.stg_trip` trong NDS trước mỗi lần nạp trip
- `D_pipelines/02_ETL_StagingDB_To_NDS/03_load_trips_to_nds.hpl`: batch copy accepted `stg_divvy_trips` + `stg_citibike_trips` → `import.stg_trip`
- `D_pipelines/02_ETL_StagingDB_To_NDS/03_merge_trip_buffer_to_nds.hpl`: set-based join city/station, derive `duration_minutes`, rồi upsert vào `nds.trip` theo `(city_sk, ride_id)`
- `D_pipelines/02_ETL_StagingDB_To_NDS/04_audit_stagingdb_to_nds_job_log.hpl`: ghi `control.etl_job_log` với `job_name = "etl_stagingdb_to_nds"`
- `D_pipelines/02_ETL_StagingDB_To_NDS/05_cleanup_nds_trip_buffer.hpl`: sau audit thành công, truncate transient `import.stg_trip`
- `D_pipelines/02_ETL_StagingDB_To_NDS/05_cleanup_staging_after_nds.hpl`: sau khi NDS load và audit thành công, truncate 4 `staging.raw_*` và 4 `staging.stg_*` tables

`import.stg_trip` là bảng làm việc transient trong DB NDS, không phải output nghiệp vụ. Bảng này là `UNLOGGED`, không có PK/index, có thể tái tạo từ Staging nếu workflow lỗi/crash; output chính thức vẫn là `nds.trip`.

**DQ rule coverage:** null, duplicate, datatype, format; reject và warning row-level details ghi `control.etl_dq_rule_result_details` (field `dq_verdict = reject|warning`), rule-level summary ghi `control.etl_dq_rule_result_analysis`. Các script `scripts/run_staging_0nf_dq.sh` và `scripts/run_staging_to_nds.sh` vẫn được giữ làm fallback/manual verification khi môi trường chưa có Hop CLI hoặc cần backfill nhanh, nhưng không còn là luồng chính trong workflow.

**Citi Bike validation runtime:** `02_validate_citibike_raw_to_staging.hpl` có 2 parameter optional: `CITIBIKE_VALIDATE_MONTH` mặc định `ALL` và `CITIBIKE_RESULT_LOAD_RUN_ID` mặc định `bootstrap_202601_202605`. Khi cần proof nhanh, chạy pipeline Citi trực tiếp với `CITIBIKE_VALIDATE_MONTH=202602` và một `CITIBIKE_RESULT_LOAD_RUN_ID` riêng; workflow 01 không truyền gì thêm nên vẫn validate full kỳ 202601–202605.

**Lệnh chạy nhanh:**

```bash
make staging-dq
make nds-load
make runtime-checks
```

### 2.3 Pipeline 3: NDS → DDS

`D_pipelines/03_ETL_NDS_To_DDS/` và `E_workflows/03_etl_nds_to_dds.hwf` hiện mới là skeleton/placeholder. DDS ETL sẽ làm sau; README này chỉ ghi nhận naming/status hiện tại của folder logic.

---



## 3. Bắt đầu nhanh — tải dữ liệu

**Windows (CMD / PowerShell / Git Bash):**

1. Cài [Git for Windows](https://git-scm.com/download/win) (có `bash`, `curl`).
2. Cài **Python 3.8+** từ [python.org](https://www.python.org/downloads/) — tick **Add python.exe to PATH**. Kiểm tra: `py -3 --version` hoặc `python --version`.
3. Cài **make** (Chocolatey: `choco install make`) nếu dùng `make datasets-full`.

**Lỗi thường gặp trên CMD:**


| Lỗi                                                       | Cách xử lý                                                                                                                              |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `WSL execvpe(/bin/bash) failed`                           | Cài Git for Windows; tắt alias `bash.exe` trong Settings → App execution aliases; hoặc mở **Git Bash**                                  |
| `syntax error near unexpected token 'from'`               | Pull bản mới (script tự sửa CRLF); hoặc `sed -i 's/\r$//' A_datasets/download_datasets.sh`                                              |
| `Python was not found` / `Microsoft Store`                | Cài [Python 3](https://www.python.org/downloads/) (tick **Add to PATH**); tắt alias `python.exe` / `python3.exe`; thử `py -3 --version` |
| `End-of-central-directory signature not found` / ZIP hỏng | Pull bản mới; `make datasets-full` tự `--force` tải lại ZIP; hoặc xóa file `.zip` lỗi rồi chạy lại                                      |


**Makefile** (chạy từ `4_Official_Hop_Project/`):

```bash
cd 4_Official_Hop_Project

make help                 # danh sách target
make datasets-check       # validate HTTP URL
make datasets-full        # full pack + ghi đè zip/csv/json + giải nén (Python)
make datasets-status      # manifest + dung lượng từng folder
make db-up                # Docker PostgreSQL STG/NDS/DDS (5434/5435/5436)
make db-status            # kiểm tra container healthy
```

Chi tiết schema DW: [mục 8](#8-schema-dw--staging-nds-dds).

**Windows (không có** `make`**):** mở **Git Bash** trong thư mục project:

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


| Thư mục         | Trạng thái | Mô tả                                                                                              |
| --------------- | ---------- | -------------------------------------------------------------------------------------------------- |
| **A_datasets**  | Sẵn sàng   | Script + tài liệu LCD V2, trip 202601–202605 ([mục 7](#7-a_datasets--phân-tích-và-hướng-dẫn-tải))  |
| **B_databases** | Sẵn sàng   | `docker-compose.yml` + init SQL B1/B2/B3; `make db-up` ([mục 8.7](#87-khởi-chạy-postgresql-local)) |
| **C_backend**   | Sẵn sàng   | Go MDM push GBFS → Hop Web Service ([mục 9](#9-push-mdm-station))                                  |
| **D_pipelines** | Đang triển khai | 3 folder logic: `01_ETL_Source_To_StagingDB`, `02_ETL_StagingDB_To_NDS`, `03_ETL_NDS_To_DDS` (pipeline 3 để sau) |
| **E_workflows** | Đang triển khai | `01_etl_source_to_stagingdb.hwf`, `02_etl_stagingdb_to_nds.hwf`, `03_etl_nds_to_dds.hwf` |
| **scripts**     | Sẵn sàng   | Runtime scripts kiểm chứng được bằng Docker/PostgreSQL: raw 0NF + DQ, Staging → NDS                |
| **metadata**    | Sẵn sàng   | RDBMS connections + `mdm-station` web service ([mục 8.8](#88-hop-metadata--biến-môi-trường))       |


---



## 5. Cấu hình Hop


| File                       | Vai trò                                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------------------- |
| `project-config.json`      | `dataSetsCsvFolder` → `${PROJECT_HOME}/A_datasets`                                                  |
| `development_configs.json` | Biến DB (5434/5435/5436), dataset paths, MDM Station — [mục 8.8](#88-hop-metadata--biến-môi-trường) |
| `metadata/rdbms/`          | `dw-staging`, `dw-control`, `dw-nds`, `dw-dds`                                                      |
| `metadata/web-service/`    | `mdm-station.json` — Hop Web Service nhận GBFS push                                                 |


Mở project trong Hop GUI: trỏ **Project home** tới thư mục `4_Official_Hop_Project`.

Sau mỗi lần clone/pull trên máy khác, chạy:

```bash
make setup-project-home
```

Lệnh này sinh lại `development_configs.json` từ `development_configs.local.json` với `PROJECT_HOME` đúng theo máy hiện tại. Không commit `development_configs.json`; các workflow/pipeline đã dùng `${PROJECT_HOME}/...` để tránh kéo đường dẫn tuyệt đối của máy khác.

---



## 6. Trạng thái triển khai


| Hạng mục                               | Ghi chú                                                                   |
| -------------------------------------- | ------------------------------------------------------------------------- |
| Ba dataset PDF (Divvy, Citi, NOAA LCD) | Trip + NOAA v2 **2026-01–2026-05** qua `download_datasets.sh`             |
| NOAA LCD v1 → v2                       | V1 deprecated; V2 giữ cùng cột hourly cho Fact table                      |
| GBFS                                   | Tùy chọn `--gbfs`; phục vụ `Dim_Station` Push                             |
| Schema DW (STG / NDS / DDS)            | SQL init + Docker + seed 2026 H1 — [mục 8](#8-schema-dw--staging-nds-dds) |
| Hop metadata (connections + MDM)       | `metadata/rdbms/*.json`, `mdm-station.json`                               |
| Hop ETL Source Files → StagingDB       | Đã có pipeline/workflow đầu tiên — `D_pipelines/01_ETL_Source_To_StagingDB`, `E_workflows/01_etl_source_to_stagingdb.hwf`; folder có nhiều `.hpl` step pipelines |
| Raw 0NF + DQ Validation                | Đã có raw tables, reject/warning tables, rule catalog/result và Hop `.hpl` visible trong workflow 01; script chỉ là fallback/manual verification |
| ETL StagingDB → NDS                    | Đã có Hop workflow visible load `nds.city`, `nds.calendar_day`, `nds.station`, `nds.weather`, `nds.trip`, sau đó audit và cleanup 8 bảng staging; script chỉ là fallback/manual verification |
| Hop ETL end-to-end                     | `D_pipelines/03_ETL_NDS_To_DDS`, `E_workflows/03_etl_nds_to_dds.hwf` hiện là skeleton/placeholder; DDS load làm sau |


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
- Một file **cả năm**; mỗi dòng có thể mix cột `Hourly`*,* `Daily`, `Monthly`* (chỉ dùng hourly cho fact grain giờ).

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

**Nguyên tắc:** `station_id` trong trip **chỉ có nghĩa trong một thành phố** — không join Divvy ↔ Citi Bike theo `station_id`. So sánh Chicago vs NYC: union fact + slice theo `Dim_City` / `city_sk`.

**Khóa trạm thống nhất (Staging → NDS → DDS):** `(city_sk, source_station_id)` — `source_station_id` = GBFS `short_name` = trip `start/end_station_id` (cast **TEXT**).


| Cặp                         | Khóa join                       | Ghi chú                                                               |
| --------------------------- | ------------------------------- | --------------------------------------------------------------------- |
| Divvy ↔ Citi Bike           | `city_sk` only                  | Union fact; **không** join `station_id` cross-city                    |
| Trip ↔ GBFS / `Dim_Station` | `city_sk` + `source_station_id` | `source_station_id` ← GBFS `short_name` = trip `start/end_station_id` |
| Trip ↔ NOAA v2              | `city_code` + `date_hour` local | CHI ↔ `USW00014819`; NYC ↔ `USW00094728`                              |
| NYC trip ↔ GBFS             | trip `6602.05` = `short_name`   | Không dùng GBFS `station_id` (UUID/số dài)                            |
| CHI trip ↔ GBFS             | trip `CHI02042` = `short_name`  | Cùng rule, format khác NYC                                            |


**Staging upsert (không** `batch_id`**):** audit qua `loaded_at` + `control.etl_extraction_control` (LSET/CET) + `control.etl_job_log`.


| Bảng staging                             | Business key upsert                  |
| ---------------------------------------- | ------------------------------------ |
| `stg_divvy_trips` / `stg_citibike_trips` | `(source_city_code, ride_id)`        |
| `stg_weather`                            | `(source_city_code, observation_ts)` |
| `stg_gbfs_station`                       | `(source_city_code, short_name)`     |


**Phân tích lịch:** không dùng `Dim_Holiday` — weekday/weekend qua `Dim_DateTime.is_weekend` (và `nds.calendar_day`).

**Cửa sổ đồng bộ:** trip `202601`–`202605` + NOAA filtered `*_01-05.csv` (cùng năm 2026).

### 7.7. Đối chiếu yêu cầu đề bài (PDF / official_topic.md)


| Yêu cầu đề bài                                                                      | LCD v2 + trip 01–05/2026                        |
| ----------------------------------------------------------------------------------- | ----------------------------------------------- |
| Dataset 3: NOAA NCEI **Local Climatological Data**                                  | **Đáp ứng** (v2 cùng sản phẩm LCD)              |
| Pull theo giờ: `HourlyDryBulbTemperature`, `HourlyPrecipitation`, `HourlyWindSpeed` | **Có**                                          |
| Join `city_code` + `date_hour`                                                      | **Có**                                          |
| Fact grain City × Station × Hour                                                    | Trip aggregate + weather denormalize theo giờ   |
| `Dim_WeatherCondition` (Clear/Rain/Snow/Fog)                                        | Rule ETL ưu tiên `HourlyPresentWeatherType`; precip > 0 chỉ là fallback cho Rain |
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
make db-up                          # Docker STG/NDS/DDS
make db-down
make db-status
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

**Biến Hop** (`development_configs.json`):


| Nhóm         | Biến chính                                                 | Ghi chú                                          |
| ------------ | ---------------------------------------------------------- | ------------------------------------------------ |
| Dataset      | `RAW_DATASET_ROOT`, `DATASETS_CSV_FOLDER`, `SAMPLE_PERIOD` | Root `A_datasets`                                |
| Trip         | `DIVVY_TRIPS_DIR`, `CITIBIKE_TRIPS_DIR`                    | Thư mục `extracted/{YYYYMM}/`                    |
| NOAA         | `NOAA_LCD_DIR`, `NOAA_LCD_CHICAGO`, `NOAA_LCD_NYC`         | File `*_01-05.csv`                               |
| GBFS / MDM   | `GBFS_STATION_DIR`, `HOP_MDM_STATION_STAGING_TABLE`        | Push → `stg_gbfs_station`                        |
| DB STG       | `STAGING_DB_*`, `CONTROL_DB_*`                              | Port **5434**                                    |
| DB NDS / DDS | `NDS_DB_*` (5435), `DDS_DB_*` (5436)                       | User `*_user`, password `*@123`                  |
| Power BI     | `POWERBI_DDS_*`                                            | `analytics_reader_user` / `analytics_reader@123` |


Chi tiết MDM + metadata: [mục 8.8](#88-hop-metadata--biến-môi-trường).

### 7.9. Lưu ý Git và dung lượng


| Nguồn                     | Ước tính (01–05/2026) |
| ------------------------- | --------------------- |
| Divvy ZIP (5 tháng)       | ~70 MB                |
| Citi Bike ZIP (5 tháng)   | ~2.2 GB               |
| NOAA v2 filtered (2 file) | ~6–7 MB               |
| **Tổng**                  | **~2.3 GB**           |


File lớn **gitignore**; mỗi thành viên chạy `download_datasets.sh` local.

---



## 8. Schema DW — Staging, NDS, DDS

Thiết kế schema cho bike-share DW (Chicago Divvy + NYC Citi Bike, kỳ mẫu **202601–202605**). SQL init: `B_databases/`; Docker: `make db-up` (ports **5434** STG+Control, **5435** NDS, **5436** DDS).

### 8.1. Tổng quan 3 tầng

- **4 dimensions** (không `Dim_Holiday`): `Dim_City`, `Dim_Station`, `Dim_DateTime`, `Dim_WeatherCondition`.
- **1 fact:** `Fact_StationHourBalance` — Periodic Snapshot, grain **City × Station × Hour**.
- **DDS layout:** **Snowflake schema** — `dim_station.city_sk` → `dim_city` (hierarchy City → Station); fact FK trực tiếp tới cả `city_sk` và `station_sk`.
- **Không** `batch_id` trên staging — chỉ `loaded_at`; upsert theo business key.
- **Raw 0NF:** `staging.raw_*` giữ giá trị dạng `TEXT`, không PK, có `load_run_id`, `source_file`, `source_row_number`, `raw_loaded_at` để kiểm DQ/duplicate.

**Source mapping:**


| A_datasets path                        | Staging              | NDS           | DDS                                   |
| -------------------------------------- | -------------------- | ------------- | ------------------------------------- |
| `A2_divvy/extracted/{YYYYMM}/*.csv`    | `stg_divvy_trips`    | `nds.trip`    | aggregate → `Fact_StationHourBalance` |
| `A1_citibike/extracted/{YYYYMM}/*.csv` | `stg_citibike_trips` | `nds.trip`    | same                                  |
| `A3_noaa_lcd_v2/LCD_*_01-05.csv`       | `stg_weather`        | `nds.weather` | measures + `Dim_WeatherCondition`     |
| `A4_mdm_station_info/*.json`           | `stg_gbfs_station`   | `nds.station` | `Dim_Station` (SCD2)                  |


```mermaid
flowchart LR
  subgraph sources [A_datasets]
    A1[A1_citibike]
    A2[A2_divvy]
    A3[A3_noaa_lcd_v2]
    A4[A4_mdm_station_info]
  end
  subgraph stg [dw_staging :5434]
    RAW[staging.raw_* 0NF]
    STG[staging.stg_*]
    CTL[control.etl_*]
  end
  subgraph nds [dw_nds :5435]
    NDS3[nds.* 3NF]
  end
  subgraph dds [dw_dds :5436]
    SNOWFLAKE["dds Snowflake: Fact + 4 Dim"]
  end
  sources --> RAW --> STG
  RAW --> DQ
  STG --> NDS3 --> SNOWFLAKE
  A4 -->|MDM Push| STG
```



**Ghi chú thiết kế:**

- Không `Dim_Holiday` / `holiday_sk` — weekday/weekend qua `Dim_DateTime.is_weekend`.
- Không `batch_id` — upsert staging + audit qua `loaded_at` + control tables.
- DQ Validation: reject và warning row-level details vào `control.etl_dq_rule_result_details` (field `dq_verdict`); rule-level summary vào `control.etl_dq_rule_result_analysis`.
- **Station join:** `(city_sk, source_station_id)`; trip id = GBFS `short_name`; không cross-city; cast TEXT.
- NOAA: `city_code` + `date_hour_local`; ưu tiên `REPORT_TYPE = 'FM-15'`; đơn vị v2 **°C, mm, m/s**.



### 8.1b. Khóa join & GBFS mapping


| Cặp                         | Khóa join                       | Ghi chú                                                               |
| --------------------------- | ------------------------------- | --------------------------------------------------------------------- |
| Divvy ↔ Citi Bike           | `city_sk` only                  | Union fact; **không** join `station_id` cross-city                    |
| Trip ↔ GBFS / `Dim_Station` | `city_sk` + `source_station_id` | `source_station_id` ← GBFS `short_name` = trip `start/end_station_id` |
| Trip ↔ NOAA                 | `city_code` + `date_hour` local | CHI ↔ `USW00014819`; NYC ↔ `USW00094728`                              |
| NYC trip ↔ GBFS             | trip `6602.05` = `short_name`   | Không dùng GBFS `station_id` (UUID/số dài)                            |
| CHI trip ↔ GBFS             | trip `CHI02042` = `short_name`  | Cùng rule, format khác NYC                                            |


```mermaid
flowchart LR
  subgraph nyc [NYC]
    T1["trip start_station_id = 6602.05"]
    G1["GBFS short_name = 6602.05"]
    DS1["source_station_id = 6602.05"]
  end
  subgraph chi [CHI]
    T2["trip start_station_id = CHI02042"]
    G2["GBFS short_name = CHI02042"]
    DS2["source_station_id = CHI02042"]
  end
  T1 --> G1 --> DS1
  T2 --> G2 --> DS2
```





### 8.2. Staging ER (`staging.*` — 4 bảng)

Port **5434** · SQL: `B1_dw_stg_postgresql/02_staging_schema.sql`

Audit: `loaded_at` only — không `batch_id`. Enum values: [§8.9](#89-enum--coded-fields).

`stg_divvy_trips` và `stg_citibike_trips` cùng cấu trúc (14 cột CSV + audit); khác `DEFAULT source_city_code` (`CHI` vs `NYC`).

```mermaid
erDiagram
  stg_divvy_trips {
    varchar ride_id PK
    varchar rideable_type
    timestamp started_at
    timestamp ended_at
    varchar start_station_name
    text start_station_id
    varchar end_station_name
    text end_station_id
    numeric start_lat
    numeric start_lng
    numeric end_lat
    numeric end_lng
    varchar member_casual
    varchar source_city_code PK
    char trip_month
    varchar source_file
    timestamp loaded_at
  }
  stg_citibike_trips {
    varchar ride_id PK
    varchar rideable_type
    timestamp started_at
    timestamp ended_at
    varchar start_station_name
    text start_station_id
    varchar end_station_name
    text end_station_id
    numeric start_lat
    numeric start_lng
    numeric end_lat
    numeric end_lng
    varchar member_casual
    varchar source_city_code PK
    char trip_month
    varchar source_file
    timestamp loaded_at
  }
  stg_weather {
    varchar source_city_code PK
    varchar noaa_station_id
    timestamp observation_ts PK
    varchar report_type
    numeric hourly_dry_bulb_temperature
    numeric hourly_precipitation
    numeric hourly_wind_speed
    varchar hourly_present_weather_type
    timestamp loaded_at
  }
  stg_gbfs_station {
    varchar source_city_code PK
    text gbfs_station_id
    text short_name PK
    varchar station_name
    numeric latitude
    numeric longitude
    int capacity
    varchar station_type
    varchar region_id
    varchar station_status
    varchar operation
    timestamp loaded_at
  }
```




| Bảng                         | PK / upsert key                      | Ghi chú                                               |
| ---------------------------- | ------------------------------------ | ----------------------------------------------------- |
| `staging.stg_divvy_trips`    | `(source_city_code, ride_id)`        | 14 cột CSV + `trip_month`, `source_file`, `loaded_at` |
| `staging.stg_citibike_trips` | `(source_city_code, ride_id)`        | Union multi-part CSV                                  |
| `staging.stg_weather`        | `(source_city_code, observation_ts)` | NOAA LCD v2 hourly, metric                            |
| `staging.stg_gbfs_station`   | `(source_city_code, short_name)`     | `short_name` → `source_station_id` khi load NDS/DDS   |




### 8.3. Control (`control.*`)

Port **5434** · SQL: `B1_dw_stg_postgresql/03_control_schema.sql`

```mermaid
erDiagram
  etl_extraction_control {
    int control_id PK
    varchar source_name UK
    varchar table_name UK
    timestamp lset
    timestamp cet
    varchar last_run_status
    int rows_extracted
    timestamp updated_at
  }
  etl_job_log {
    int log_id PK
    varchar job_name
    varchar source_name
    timestamp started_at
    timestamp finished_at
    varchar status
    int total_rows_count
    int success_rows_count
    int failed_rows_count
    text error_message
  }
```




| Schema    | Bảng                     | PK / UK                                      | Ghi chú                                                               |
| --------- | ------------------------ | -------------------------------------------- | --------------------------------------------------------------------- |
| `control` | `etl_extraction_control` | `control_id`; UK `(source_name, table_name)` | LSET/CET: `divvy_trips`, `citibike_trips`, `noaa_lcd`, `gbfs_station` |
| `control` | `etl_job_log`            | `log_id`                                     | Audit từng lần chạy workflow/pipeline                                 |




### 8.4. NDS 3NF (`nds.*` — 5 bảng)

Port **5435** · SQL: `B2_dw_nds_postgresql/02_nds_schema.sql`

Migration `B2_dw_nds_postgresql/05_import_trip_buffer.sql` tạo thêm `import.stg_trip` làm buffer transient cho trip bulk load. Buffer này nằm cùng DB NDS để Hop có thể batch copy từ Staging rồi PostgreSQL merge set-based vào `nds.trip`; nó không thuộc mô hình 3NF nghiệp vụ.

```mermaid
erDiagram
  nds_city ||--o{ nds_station : city_sk
  nds_city ||--o{ nds_trip : city_sk
  nds_city ||--o{ nds_weather : city_sk
  nds_station ||--o{ nds_trip : start_station_sk
  nds_station ||--o{ nds_trip : end_station_sk
  nds_city {
    int city_sk PK
    varchar city_code UK
    varchar city_name
    varchar timezone
    varchar noaa_station_id
    varchar gbfs_system_id
  }
  nds_station {
    bigint station_sk PK
    int city_sk FK
    text source_station_id
    varchar station_name
    numeric latitude
    numeric longitude
    int capacity
    varchar station_status
    timestamp effective_from
    timestamp effective_to
    varchar row_status
    boolean is_current
    timestamp loaded_at
  }
  nds_calendar_day {
    int calendar_day_sk PK
    date calendar_date UK
    smallint day_of_week
    boolean is_weekend
    smallint month
    varchar season
  }
  nds_weather {
    bigint weather_sk PK
    int city_sk FK
    timestamp observation_hour UK
    varchar report_type
    numeric temperature_c
    numeric precipitation_mm
    numeric wind_speed_ms
    varchar present_weather
    varchar weather_category
    timestamp loaded_at
  }
  nds_trip {
    bigint trip_sk PK
    int city_sk FK
    varchar ride_id UK
    varchar rideable_type
    timestamp started_at
    timestamp ended_at
    text start_station_id
    text end_station_id
    bigint start_station_sk FK
    bigint end_station_sk FK
    numeric start_lat
    numeric start_lng
    numeric end_lat
    numeric end_lng
    varchar member_casual
    numeric duration_minutes
    char trip_month
    timestamp loaded_at
  }
```




| Bảng               | PK                                 | Ghi chú                                                                                     |
| ------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------- |
| `nds.city`         | `city_sk`                          | CHI, NYC; timezone, NOAA v2 id                                                              |
| `nds.station`      | `station_sk`                       | UNIQUE `(city_sk, source_station_id)` per SCD2 row; `source_station_id` = GBFS `short_name` |
| `nds.calendar_day` | `calendar_day_sk`                  | `is_weekend`, `season` — thay vai trò phân tích calendar                                    |
| `nds.weather`      | `weather_sk`                       | UNIQUE `(city_sk, observation_hour)`                                                        |
| `nds.trip`         | `trip_sk`; UK `(city_sk, ride_id)` | FK `start_station_sk`, `end_station_sk` → `nds.station`                                     |


`nds.calendar_day` độc lập (không FK sang `trip`/`weather`); join phân tích qua `calendar_date` ↔ `started_at` / `observation_hour`.

### 8.5. DDS Snowflake (`dds.*` — 4 Dim + 1 Fact)

- Port **5436** · SQL: `B3_dw_dds_postgresql/02_dds_schema.sql`
- **Schema type:** **Snowflake** (không phải Star thuần) — dimension có hierarchy: `dim_station` FK `city_sk` → `dim_city` (City → Station). Các dimension còn lại (`dim_datetime`, `dim_weather_condition`) nối trực tiếp fact; không có hierarchy bổ sung.
- **Fact type:** Periodic Snapshot
- **Fact Grain:** City × Station × Hour
- **Unique Key in Fact table:** `(city_sk, station_sk, datetime_sk)`

```mermaid
erDiagram
  dim_city {
    int city_sk PK
    varchar city_code UK
    varchar city_name
    varchar timezone
    varchar noaa_station_id
    varchar gbfs_system_id
  }
  dim_station {
    bigint station_sk PK
    int city_sk FK
    text source_station_id
    varchar station_name
    numeric latitude
    numeric longitude
    int capacity
    varchar station_status
    timestamp effective_from
    timestamp effective_to
    varchar row_status
    boolean is_current
  }
  dim_datetime {
    int datetime_sk PK
    date date UK
    smallint hour UK
    smallint day_of_week
    boolean is_weekend
    boolean is_peak_hour
    smallint month
    varchar season
  }
  dim_weather_condition {
    int weather_condition_sk PK
    varchar weather_category UK
    varchar precipitation_band
  }
  fact_station_hour_balance {
    bigint station_hour_balance_sk PK
    int city_sk FK
    bigint station_sk FK
    int datetime_sk FK
    int weather_condition_sk FK
    int trips_started
    int trips_ended
    int net_flow
    int abs_imbalance
    int member_trip_count
    int casual_trip_count
    int electric_trip_count
    int classic_trip_count
    numeric avg_duration_member_minutes
    numeric avg_duration_casual_minutes
    numeric temperature
    numeric precipitation
    numeric wind_speed
    timestamp loaded_at
  }
  dim_city ||--o{ fact_station_hour_balance : city_sk
  dim_station ||--o{ fact_station_hour_balance : station_sk
  dim_datetime ||--o{ fact_station_hour_balance : datetime_sk
  dim_weather_condition ||--o{ fact_station_hour_balance : weather_condition_sk
  dim_city ||--o{ dim_station : city_sk
```




| Dimension                   | SCD        | Hierarchy / ghi chú                                 |
| --------------------------- | ---------- | --------------------------------------------------- |
| `dds.dim_city`              | Type 1     | Cấp trên của `dim_station` (snowflake arm)          |
| `dds.dim_station`           | **Type 2** | FK `city_sk` → `dim_city`; `source_station_id` TEXT |
| `dds.dim_datetime`          | None       | Phẳng — nối trực tiếp fact                          |
| `dds.dim_weather_condition` | Type 1     | Phẳng — nối trực tiếp fact                          |


**Không có** `holiday_sk` trên fact (quyết định nhóm — dùng `dim_datetime.is_weekend`).

### 8.6. Seed data (DDL)


| Đối tượng                   | Nội dung seed                                                       |
| --------------------------- | ------------------------------------------------------------------- |
| `dds.dim_city`              | CHI + NYC                                                           |
| `dds.dim_weather_condition` | Clear, Rain, Snow, Fog                                              |
| `dds.dim_datetime`          | Mọi giờ **2026-01-01 → 2026-05-31** + `is_weekend` + `is_peak_hour` |
| `nds.city`                  | CHI + NYC (mirror) — bootstrap bằng seed, refresh/upsert trong StagingDB → NDS workflow |
| `nds.calendar_day`          | Mọi ngày 2026-01-01 → 2026-05-31 — bootstrap bằng seed, refresh/upsert theo khoảng ngày staging trong StagingDB → NDS workflow |


**Không seed** US federal holidays.

### 8.7. Khởi chạy PostgreSQL local

```bash
cd 4_Official_Hop_Project
make db-up          # docker compose up -d (B_databases/)
make db-status      # kiểm tra 3 container healthy
make db-down        # dừng containers
```


| Service           | Port | Databases                                 |
| ----------------- | ---- | ----------------------------------------- |
| `dw-stg-postgres` | 5434 | `dw_staging`, `dw_control` |
| `dw-nds-postgres` | 5435 | `dw_nds`                                  |
| `dw-dds-postgres` | 5436 | `dw_dds`                                  |




### 8.8. Hop metadata & biến môi trường

**Metadata** (`metadata/`):

```text
metadata/
├── rdbms/dw-staging.json, dw-control.json, dw-nds.json, dw-dds.json
├── web-service/mdm-station.json
├── workflow-run-configuration/local.json
└── pipeline-run-configuration/local.json
```

**MDM Station** (theo pattern `3_Hop_ETL_Test` — retry/timeout do Backend quản lý, không khai báo trong Hop):


| Biến                            | Giá trị dev                                      | Ghi chú                                      |
| ------------------------------- | ------------------------------------------------ | -------------------------------------------- |
| `HOP_MDM_API_HOST`              | `127.0.0.1`                                      | Bind host Hop Server                         |
| `HOP_MDM_API_PORT`              | `8080`                                           |                                              |
| `HOP_MDM_API_URL`               | `http://localhost:8080/hop/webService/?service=` | Nối `HOP_MDM_STATION_SERVICE_ID`             |
| `HOP_MDM_STATION_API_KEY`       | `local-dev-mdm-key`                              | Header `X-API-Key`                           |
| `HOP_MDM_STATION_SERVICE_ID`    | `mdm-station`                                    | Khớp `metadata/web-service/mdm-station.json` |
| `HOP_MDM_STATION_STAGING_TABLE` | `stg_gbfs_station`                               | Bảng staging sau push                        |
| `HOP_MDM_ALLOWED_OPERATIONS`    | `INSERT,UPDATE,DELETE`                           |                                              |


**DB credentials** (local dev — khớp SQL init `B_databases/`):


| Layer    | User                    | Password               |
| -------- | ----------------------- | ---------------------- |
| Staging  | `hop_staging_user`      | `hop_staging@123`      |
| Control  | `hop_control_user`      | `hop_control@123`      |
| NDS      | `hop_nds_user`          | `hop_nds@123`          |
| DDS      | `hop_dds_user`          | `hop_dds@123`          |
| Power BI | `analytics_reader_user` | `analytics_reader@123` |




### 8.9. Enum / coded fields

Các cột dưới đây dùng `VARCHAR` (không phải PostgreSQL `ENUM`). Giá trị hợp lệ được ghi trong SQL (`B_databases/*/04_enum_field_notes.sql`) qua `COMMENT ON COLUMN`.

#### Staging (`staging.*`)


| Bảng / cột                          | Giá trị hợp lệ                                        | Ghi chú                                 |
| ----------------------------------- | ----------------------------------------------------- | --------------------------------------- |
| `stg_*_trips.source_city_code`      | `CHI`, `NYC`                                          | Khớp `city_code` mọi tầng               |
| `stg_*_trips.rideable_type`         | `classic_bike`, `electric_bike`                       | Từ trip CSV                             |
| `stg_*_trips.member_casual`         | `member`, `casual`                                    | Từ trip CSV                             |
| `stg_weather.source_city_code`      | `CHI`, `NYC`                                          |                                         |
| `stg_weather.report_type`           | `FM-15`, `FM-16`, `FM-12` (hourly); loại `SOD`, `SOM` | ETL ưu tiên `FM-15`                     |
| `stg_gbfs_station.source_city_code` | `CHI`, `NYC`                                          |                                         |
| `stg_gbfs_station.station_type`     | `classic`, `e_bike` (tùy GBFS; có thể NULL)           |                                         |
| `stg_gbfs_station.station_status`   | `open`, `closed`, `maintenance`                       | DW normalized; mặc định `open`          |
| `stg_gbfs_station.operation`        | `INSERT`, `UPDATE`, `DELETE`                          | MDM push (`HOP_MDM_ALLOWED_OPERATIONS`) |




#### Control


| Bảng / cột                               | Giá trị hợp lệ                                              |
| ---------------------------------------- | ----------------------------------------------------------- |
| `etl_extraction_control.source_name`     | `divvy_trips`, `citibike_trips`, `noaa_lcd`, `gbfs_station` |
| `etl_extraction_control.last_run_status` | `SUCCESS`, `FAILED`, `RUNNING`, `SKIPPED`                   |
| `etl_job_log.status`                     | `SUCCESS`, `FAILED`, `RUNNING`, `SKIPPED`, `DQ_PASSED`, `DQ_PARTIAL_PASSED`, `DQ_FAILED` |




#### NDS (`nds.*`)


| Bảng / cột                 | Giá trị hợp lệ                       | Ghi chú                                                                                                     |
| -------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `city.city_code`           | `CHI`, `NYC`                         |                                                                                                             |
| `city.gbfs_system_id`      | `divvy`, `citibike`                  |                                                                                                             |
| `station.station_status`   | `open`, `closed`, `maintenance`      | Ví dụ: trạm đang mở vs tạm đóng                                                                             |
| `station.row_status`       | `active`, `deleted`                  | SCD2 — `active` = phiên bản hiện tại                                                                        |
| `calendar_day.day_of_week` | `1`–`7`                              | ISO: 1=Thứ Hai … 7=Chủ Nhật                                                                                 |
| `calendar_day.season`      | `winter`, `spring`, `summer`, `fall` | Theo tháng Bắc bán cầu: T12–T2 / T3–T5 / T6–T8 / T9–T11. Kỳ mẫu 202601–202605 chỉ có **winter**, **spring** |
| `weather.report_type`      | `FM-15`, `FM-16`, `FM-12`            | Giống staging                                                                                               |
| `weather.weather_category` | `Clear`, `Rain`, `Snow`, `Fog`       | Rule ETL ưu tiên `HourlyPresentWeatherType`: SN/SG/PL → Snow; FG/BR/HZ → Fog; RA/DZ/TS/GR hoặc precip > 0 → Rain; còn lại Clear |
| `trip.rideable_type`       | `classic_bike`, `electric_bike`      |                                                                                                             |
| `trip.member_casual`       | `member`, `casual`                   |                                                                                                             |




#### DDS (`dds.*`)


| Bảng / cột                                 | Giá trị hợp lệ                       | Ghi chú                                       |
| ------------------------------------------ | ------------------------------------ | --------------------------------------------- |
| `dim_city.city_code`                       | `CHI`, `NYC`                         |                                               |
| `dim_city.gbfs_system_id`                  | `divvy`, `citibike`                  |                                               |
| `dim_station.station_status`               | `open`, `closed`, `maintenance`      | Giống `nds.station`                           |
| `dim_station.row_status`                   | `active`, `deleted`                  | SCD2                                          |
| `dim_datetime.day_of_week`                 | `1`–`7`                              | ISO                                           |
| `dim_datetime.hour`                        | `0`–`23`                             | Giờ local                                     |
| `dim_datetime.month`                       | `1`–`12`                             |                                               |
| `dim_datetime.season`                      | `winter`, `spring`, `summer`, `fall` | Cùng rule `calendar_day.season`               |
| `dim_datetime.is_peak_hour`                | `TRUE`, `FALSE`                      | `TRUE` = ngày thường (T2–T6) giờ 7, 8, 17, 18 |
| `dim_weather_condition.weather_category`   | `Clear`, `Rain`, `Snow`, `Fog`       | Seed cố định                                  |
| `dim_weather_condition.precipitation_band` | `none`, `light_moderate`, `snow`     | Seed cố định                                  |


**Ví dụ** `season` **(seed** `03_seed_dimensions.sql`**):**


| Tháng     | `season` |
| --------- | -------- |
| 12, 1, 2  | `winter` |
| 3, 4, 5   | `spring` |
| 6, 7, 8   | `summer` |
| 9, 10, 11 | `fall`   |


---

## 9. Push MDM Station

Luồng này cho phép **Go MDM Station** gửi thay đổi master data GBFS (thông tin trạm) tới Apache Hop theo thời gian thực. Backend POST từng trạm một tới **Hop Sync Web Service**. Hop kiểm tra API key, đối chiếu `INSERT` / `UPDATE` / `DELETE` với `nds.station`, rồi upsert `staging.stg_gbfs_station` (kèm cột `operation`). Các bước Staging→NDS và NDS→DDS phía sau xử lý soft-delete / tái kích hoạt (reactivation).

### Diễn biến end-to-end

1. **Backend** (`C_backend/C1_mdm_station_info`) đọc JSON (mặc định `A_datasets/A4_mdm_station_info/new_mdm_station_information.json`), dựng payload `{operation, sent_at, data}`, POST kèm **HTTP Basic Auth** (`cluster`/`cluster`) và header **`X-API-Key`**.
2. **Hop Server** nhận `POST /hop/webService/?service=mdm-station`.
3. **Hop** chạy `00_mdm_service_redirection.hpl`, rồi (qua Pipeline Executor) chạy `01_store_pushed_mdm_station_from_backend_to_staging.hpl`.
4. **Staging** upsert một dòng trong `staging.stg_gbfs_station` theo khóa `(source_city_code, short_name)`.
5. ETL batch sau đó: Staging→NDS soft-close hoặc tái kích hoạt `nds.station`; NDS→DDS cập nhật `dds.dim_station` (SCD2 / `row_status`).

**Không** gắn các pipeline MDM vào `01_etl_source_to_stagingdb.hwf`. Workflow là batch (chạy xong rồi thoát); **Hop Server** mới là listener nhận HTTP.

```mermaid
flowchart TB
  subgraph BE [Go Backend]
    GoPush["C1_mdm_station_info go run ."]
    JSON["A_datasets/A4_mdm_station_info/new_mdm_station_information.json"]
  end
  subgraph HopServer [Hop Server :8080]
    WS["/hop/webService/?service=mdm-station"]
    Entry["00_mdm_service_redirection.hpl"]
    Store["01_store_pushed_mdm_station_from_backend_to_staging.hpl"]
  end
  subgraph DW [Data Warehouse]
    STG[(staging.stg_gbfs_station)]
    NDS[(nds.station)]
    DDS[(dds.dim_station)]
  end
  JSON --> GoPush
  GoPush -->|"POST + Basic Auth + X-API-Key"| WS
  WS --> Entry
  Entry -->|PipelineExecutor| Store
  Store --> STG
  STG -->|"02 ETL Staging to NDS"| NDS
  NDS -->|"03 D2 Load Dim Station"| DDS
```

| Bước | Pipeline | Vai trò |
|------|----------|---------|
| 1 — Entry Web Service | `D_pipelines/00_ETL_Push_Station_MDM_To_StagingDB/00_mdm_service_redirection.hpl` | Kiểm tra API key; gọi executor hoặc trả 401 |
| 2 — Lưu trạm | `…/01_store_pushed_mdm_station_from_backend_to_staging.hpl` | Parse JSON, reconcile với NDS, upsert staging |

Metadata: `metadata/web-service/mdm-station.json` chỉ trỏ tới bước 1.

### Biến cấu hình

| Key | Ví dụ | Mục đích |
|-----|-------|----------|
| `HOP_MDM_API_HOST` | `127.0.0.1` | Host bind của Hop Server |
| `HOP_MDM_API_PORT` | `8080` | Port Hop Server |
| `HOP_MDM_API_URL` | `http://localhost:8080/hop/webService/?service=` | Base URL Web Service |
| `HOP_MDM_STATION_API_KEY` | `local-dev-mdm-key` | Giá trị `X-API-Key` kỳ vọng |
| `HOP_MDM_STATION_SERVICE_ID` | `mdm-station` | Tham số `?service=` và `name` trong metadata |
| `HOP_MDM_ALLOWED_OPERATIONS` | `INSERT,UPDATE,DELETE` | Các giá trị `operation` được phép |

### Xác thực (hai lớp)

1. Basic Auth của Hop Server (Jetty): `cluster` / `cluster`
2. Header MDM `X-API-Key` — kiểm tra trong pipeline redirection

### `operation` vs `row_status` vs `station_status`

| Trường | Giá trị | Ý nghĩa |
|--------|---------|---------|
| `stg_gbfs_station.operation` | `INSERT`, `UPDATE`, `DELETE` | Ý định MDM của lần push này |
| `nds/dds.row_status` | `active`, `deleted` | Vòng đời bản ghi (SCD soft-delete) |
| `station_status` | `open`, `closed`, `maintenance` | Trạng thái vận hành của trạm |

Quy tắc NDS: đã có dòng active + INSERT/UPDATE → **cập nhật tại chỗ**; DELETE → soft-close (`row_status=deleted`, `is_current=false`, gán `effective_to`); tái kích hoạt sau DELETE → **thêm dòng mới** với `effective_from=NOW()`.

### Cách chạy

```bash
cd 4_Official_Hop_Project
make setup-project-home   # scripts/setup_project_home.sh
make db-up
make mdm-start            # scripts/start_mdm_station_services.sh
# chỉ Hop Server: SKIP_GO_PUSH=1 make mdm-start
# ghi đè: HOP_HOME, HOP_PROJECT_NAME=HCMUS_Master_IS_BI_Hop_ETL_Official,
#         HOP_ENVIRONMENT_NAME=Hop_ETL_Official_Configs
```

Smoke test Go: `go run . -city CHI -operation INSERT -limit 5 -input A_datasets/A4_mdm_station_info/new_mdm_station_information.json`

Ví dụ curl:

```bash
curl -u cluster:cluster -H "Content-Type: application/json" -H "X-API-Key: local-dev-mdm-key" \
  -d '{"operation":"INSERT","sent_at":"2026-07-12T12:00:00Z","data":{"source_city_code":"CHI","gbfs_station_id":"1","short_name":"CHI02042","station_name":"Demo","latitude":41.88,"longitude":-87.62,"capacity":10,"station_status":"open"}}' \
  "http://127.0.0.1:8080/hop/webService/?service=mdm-station"
```

Load file hàng loạt (`04_load_gbfs` → raw → validate → stg) vẫn dùng cho bootstrap; MDM push là đường online khi master data trạm thay đổi.

---

*HCMUS Master IS — Advanced Business Intelligence — Nhóm 8.*
