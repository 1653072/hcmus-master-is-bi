# 4_Official_Hop_Project — Bike-share DW (Hop ETL)

Dự án Apache Hop chính thức cho đề tài **Xây dựng Data Warehouse phân tích dữ liệu để lập kế hoạch điều phối hệ thống xe đạp công cộng tại Chicago và New York**.

**Đối chiếu đề bài:** [official_topic.md](../0_topic_exploration/official_topic.md) · [PDF đăng ký](../0_topic_exploration/official_topic_for_report.pdf)

**Kỳ dữ liệu triển khai:** **01–05/2026** (Divvy, Citi Bike, NOAA LCD V2).

---

## Mục lục

1. [Cấu trúc thư mục](#1-cấu-trúc-thư-mục)
2. [Luồng dữ liệu tóm tắt](#2-luồng-dữ-liệu-tóm-tắt)
3. [Bắt đầu nhanh — tải raw](#3-bắt-đầu-nhanh--tải-raw)
4. [Thành phần theo thư mục](#4-thành-phần-theo-thư-mục)
5. [Cấu hình Hop](#5-cấu-hình-hop)
6. [Trạng thái triển khai](#6-trạng-thái-triển-khai)

---

## 1. Cấu trúc thư mục

```text
4_Official_Hop_Project/
├── README.md                      # Tài liệu này (master doc — bổ sung dần)
├── development_configs.json       # Biến môi trường Hop
├── project-config.json            # Hop project config
│
├── A_datasets/                    # Trip + NOAA + GBFS (xem A_datasets/README.md)
│   ├── README.md
│   ├── download_datasets.sh
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
- **NOAA:** LCD **v2** bulk 2026; ETL dùng file lọc `*_01-05.csv` (metric °C, mm, m/s).

Chi tiết dataset: [A_datasets/README.md](A_datasets/README.md).

---

## 3. Bắt đầu nhanh — tải raw

```bash
cd 4_Official_Hop_Project/A_datasets
chmod +x download_datasets.sh

# Validate URL
./download_datasets.sh --urls-only

# Tải đủ 01–05/2026 (~2.3 GB; Citi Bike chiếm phần lớn)
./download_datasets.sh --extract --gbfs
```

Sau khi chạy, kiểm tra `A_datasets/manifest.json`.

---

## 4. Thành phần theo thư mục


| Thư mục         | Trạng thái        | Mô tả                                        |
| --------------- | ----------------- | -------------------------------------------- |
| **A_datasets** | **Sẵn sàng** | Script + tài liệu LCD v2, trip 202601–202605 |
| **B_databases** | Khung placeholder | Docker Compose + init SQL (TODO)             |
| **C_backend**   | Khung placeholder | Go MDM push GBFS → Hop API (TODO)            |
| **D_pipelines** | TODO              | Pull staging, NDS, DDS load                  |
| **E_workflows** | TODO              | Orchestration hàng ngày                      |
| **metadata**    | TODO              | Connection STG / NDS / DDS                   |


---

## 5. Cấu hình Hop


| File                       | Vai trò                                                   |
| -------------------------- | --------------------------------------------------------- |
| `project-config.json`      | `dataSetsCsvFolder` → `${PROJECT_HOME}/A_datasets`          |
| `development_configs.json` | Biến DB / API (template từ demo — cập nhật khi có Docker) |
| `metadata/`                | File `.json` kết nối Hop tới PostgreSQL                   |


Mở project trong Hop GUI: trỏ **Project home** tới thư mục `4_Official_Hop_Project`.

---

## 6. Trạng thái triển khai


| Hạng mục                               | Ghi chú                                                   |
| -------------------------------------- | --------------------------------------------------------- |
| Ba dataset PDF (Divvy, Citi, NOAA LCD) | Trip + NOAA v2 **2026-01..05** qua `download_datasets.sh` |
| NOAA LCD v1 → v2                       | v1 deprecated; v2 giữ cùng cột hourly cho fact            |
| GBFS                                   | Tùy chọn `--gbfs`; phục vụ `Dim_Station` Push             |
| Hop ETL end-to-end                     | Chưa implement — `D_pipelines/`, `E_workflows/`           |


---

*HCMUS Master IS — Advanced Business Intelligence — Nhóm 8.*