# Data Warehouse Topic Exploration (v2)

Transportation-focused topics proposed by the team, with **strict dataset validation** (download tested where possible on 2026-06-28).

**Alignment:** [`2_Guidelines/README.md`](../2_Guidelines/README.md) and [`1_Project_Requirements`](../1_Project_Requirements/) — ≥3 sources, messy data, NDS 3NF → DDS Star/Snowflake, one manager role, multi-dataset aggregation.

**Note on Kaggle:** Course guidelines prefer **raw / official sources** over pre-packaged Kaggle mining sets. `TrafficVolumeData.csv` on Kaggle is a mirror of the UCI **Metro Interstate Traffic Volume** dataset; prefer **UCI** or **MnDOT** as the primary source.

**Relation to v1:** [`topic_exploration.md`](topic_exploration.md) covers HR/global business topics. This file covers **traffic congestion** and **bike-share dispatch** only.

---

## Table of Contents

1. [Category 1 — Traffic Congestion Factor Analysis (I-94 Minneapolis)](#category-1--traffic-congestion-factor-analysis-i-94-minneapolis)
2. [Category 2 — Shared Bike Fleet Dispatch & Demand Analytics](#category-2--shared-bike-fleet-dispatch--demand-analytics)
3. [Strict Dataset Validation Summary](#strict-dataset-validation-summary)
4. [Recommended Priority](#recommended-priority)
5. [GBFS, MDM & Hybrid ETL (Category 2)](#gbfs-mdm--hybrid-etl-category-2)
6. [Open Questions](#open-questions)

---

## Category 1 — Traffic Congestion Factor Analysis (I-94 Minneapolis)

### Topic Name

**Highway Congestion & Traffic Volume Factor Analytics (I-94 Minneapolis–St Paul Corridor)**

Phân tích các yếu tố ảnh hưởng đến ùn tắc / lưu lượng giao thông trên tuyến I-94 (ATR Station 301), gồm thời tiết, ngày lễ, giờ cao điểm, và so sánh với các trạm đếm khác của MnDOT.

### 3.1 Managerial Role

**Traffic Operations Manager (Trưởng phòng Vận hành Giao thông)** — responsible for monitoring corridor performance, identifying congestion drivers, and advising ramp metering / incident response / maintenance scheduling for the I-94 westbound corridor and peer MnDOT count stations.

### 3.2 Business Use Cases

- Weekly/monthly dashboards: **when and why** does traffic volume spike or drop (hour × day-of-week × holiday × weather)?
- Rank impact factors: temperature, rain, snow, cloud cover, US holidays, Minnesota State Fair vs. normal weekdays.
- Compare **ATR Station 301 (I-94)** against **other MnDOT ATR hourly stations** in the same region to detect corridor-specific vs. regional patterns.
- Support prescriptive actions: staffing for peak hours, winter road ops, holiday travel advisories.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

| Need | OLTP / single CSV | Data Warehouse |
|------|-------------------|----------------|
| Multi-source integration | One file already embeds weather; no cross-system history | Blend **MnDOT traffic**, **NOAA weather**, **holiday master**, **multi-station ATR** with conformed `Dim_DateTime`, `Dim_Weather`, `Dim_Corridor` |
| Time-series aggregation | Re-run pandas/SQL ad hoc | Pre-modelled **hourly/daily facts** for OLAP: AVG/SUM volume by factor combinations |
| Historical analysis | 2012–2018 static export | SCD on station metadata; incremental loads for new MnDOT years |
| Manager self-service | Data science notebook | Power BI / SSAS cube on **Star Schema** |

**Suggested DDS (Star Schema):**

- **Fact_TrafficVolumeHour** — grain: `corridor_station_id × date_hour` — measures: `traffic_volume`, `vehicle_count` (from MnDOT multi-station)
- **Fact_WeatherHour** — grain: `weather_station_id × date_hour` — measures: temp, precip, wind, humidity (from NOAA; can also compare to embedded weather in traffic file for DQ)
- **Dimensions:** `Dim_DateTime` (hour, dow, month, is_peak_hour), `Dim_Holiday` (US + MN regional), `Dim_WeatherCondition`, `Dim_CorridorStation`

**Join keys:** `date_hour` (CST, truncated to hour) between traffic and NOAA; `calendar_date` for holidays; `station_id` + `date_hour` within MnDOT ATR family.

**Example aggregations:**

- `AVG(traffic_volume)` by `weather_main` × `is_holiday` × `hour_of_day`
- `SUM(traffic_volume)` YoY for same `month × dow`
- Correlation-style KPI: volume delta on rainy vs. clear hours (Minneapolis MSP weather station)

### 3.4 Three Datasets (validated & corrected)

#### Team's original trio — validation

| # | Original dataset | Verdict | Issue |
|---|------------------|---------|-------|
| 1 | **TrafficVolumeData.csv (Kaggle)** | **PARTIAL** | Same data as UCI Metro Interstate Traffic Volume — I-94 ATR 301, Minneapolis area, hourly 2012–2018. Kaggle OK as mirror; **prefer UCI/MnDOT** per course guidelines. |
| 2 | **UCI Air Quality Dataset** | **FAIL** | Collected in an **Italian city** (road-level sensor), 2004–2005 — **not Minneapolis**. Joining on `datetime` would be **geographically invalid**. |
| 3 | **Urban Traffic Flow** (generic) | **FAIL** | Ambiguous name — common hits are **Glasgow** (Zenodo), **Luzern/Hamburg** (UTD19), or **synthetic demo CSVs** — **none are Minneapolis I-94**. |

> Your team's geographic note is **correct**: if using I-94 Minneapolis traffic, weather and holidays must be **Minneapolis/US**, not Valencia air quality or European urban flow sensors.

#### Recommended replacement trio (PASS)

| # | Dataset | Role | Download |
|---|---------|------|----------|
| 1 | **UCI Metro Interstate Traffic Volume** (primary transaction fact) | Hourly `traffic_volume` at MN DoT ATR 301, I-94 westbound; includes embedded holiday/weather columns | https://archive.ics.uci.edu/dataset/492/metro+interstate+traffic+volume (396 KB; use page **Download** button) |
| 2 | **NOAA NCEI Local Climatological Data (LCD)** — Minneapolis MSP | Independent hourly weather for **MINNEAPOLIS ST. PAUL INTL AIRPORT** (station file `72658014922.csv`) | https://www.ncei.noaa.gov/data/local-climatological-data/access/ (e.g. `.../2016/72658014922.csv`) — **HTTP 200 verified** |
| 3 | **MnDOT ATR Hourly Volume Reports** (multi-station Excel) | Additional corridor/regional count stations; wide Excel format (messy ETL) | https://dot.state.mn.us/traffic/data/reports-hrvol-atr.html (2017–2024 yearly Excel downloads) |

**Optional 4th master (push dimension):** US federal + MN regional holiday calendar derived from traffic `holiday` column or OPM/US calendar CSV — not required if holiday already in dataset 1, but good for **MDM / SCD Type 1** exercise.

**Join validation (Category 1):**

| Source A | Source B | Join key | Overlap | Result |
|----------|----------|----------|---------|--------|
| UCI traffic | NOAA MSP LCD | `date_time` → `DATE` truncated to hour (CST) | 2012–2018 | **PASS** |
| UCI traffic | MnDOT ATR Excel | `station_id` (301) + hour-of-year | 2017–2018 partial with UCI | **PARTIAL** — pick overlapping years or use MnDOT as primary for 2017+ |
| UCI traffic | UCI Air Quality (original) | datetime only | None (Italy vs US) | **FAIL** |

---

## Category 2 — Shared Bike Fleet Dispatch & Demand Analytics

### Topic Name

**Multi-City Bike-Share Fleet Dispatch & Demand Analytics (Chicago Divvy + NYC Citi Bike)**

Xây dựng kho dữ liệu hỗ trợ điều phối và phân tích nhu cầu hệ thống xe đạp chia sẻ — trạm nào thiếu xe, khu vực nào quá tải, yếu tố thời tiết / ngày lễ / giờ cao điểm.

### 3.1 Managerial Role

**Head of Shared Bike Fleet Dispatch (Trưởng phòng Điều phối Xe đạp công cộng)** — owns weekly rebalancing plans, truck routes, station fill targets, and seasonal staffing across operating cities.

### 3.2 Business Use Cases

- Each week: which **stations** are net exporters vs. net importers (bike surplus/deficit)?
- Identify **overload zones** by hour × neighborhood × city (Chicago vs. NYC).
- Quantify drivers: **temperature, precipitation, wind**, US holidays, weekday peak vs. weekend leisure.
- Plan seasonal ops: winter demand drop, summer peak rebalancing crews.
- Compare **member vs. casual** ride patterns for fleet sizing.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

Bike-share OLTP (operator apps) handles live check-out/check-in. The dispatch manager needs **historical integrated analytics**:

| Need | OLTP / monthly CSV | Data Warehouse |
|------|-------------------|----------------|
| Trip + weather + calendar | Manual joins per city each week | Unified **`Dim_City`**, **`Dim_Station`**, **`Dim_DateTime`**, **`Dim_Weather`** |
| Cross-city comparison | Divvy vs Citi different schemas | Conformed **`Fact_BikeTrip`** with city surrogate key; ETL handles column renames |
| Rebalancing metrics | Not stored in source trips | Derived **`Fact_StationHourBalance`** (starts − ends) aggregated in DDS |
| OLAP | Slow on millions of trip rows | Galaxy schema + cube: drill city → station → hour |

**Suggested DDS (Galaxy schema — with optional snowflaked dimensions):**

> **Schema check (2026-06-28):** **Multiple fact tables** that share conformed dimensions = **Galaxy (constellation) schema**, not Snowflake. **Snowflake** only means **normalized dimensions** (e.g. `Dim_City` → `Dim_Market`), and can appear *inside* a Galaxy. Course allows Star, Snowflake, or Galaxy ([`2_Guidelines` §7.2](../2_Guidelines/README.md)).

**Shared conformed dimensions** (used by more than one fact):

- `Dim_City` → snowflake to `Dim_Market` (region / country — **snowflake sub-structure**)
- `Dim_Station` (from GBFS MDM push + SCD)
- `Dim_DateTime` (hour, dow, peak flags)
- `Dim_Holiday`

**Fact tables** (each is its own star “point”; together = Galaxy):

| Fact | Grain | Measures | Primary dimensions |
|------|-------|----------|-------------------|
| **Fact_BikeTrip** | one row per trip | trip count (1), duration (derived) | `Dim_City`, `Dim_Station` (start/end role), `Dim_DateTime`, `Dim_Holiday` |
| **Fact_StationHourBalance** | `city × station × date_hour` | `trips_started`, `trips_ended`, `net_flow` | `Dim_City`, `Dim_Station`, `Dim_DateTime` |
| **Fact_WeatherHour** | `city × date_hour` | temp, precip, wind | `Dim_City`, `Dim_DateTime`, `Dim_Weather` |

**Galaxy join pattern:** do **not** join fact-to-fact directly in DDS. Analysis joins through **shared dimensions** (e.g. `Dim_City` + `Dim_DateTime`) or builds a **semantic layer / cube** that relates `Fact_StationHourBalance` to `Fact_WeatherHour` on `city_sk` + `datetime_sk`.

**Simpler Star-only alternative** (if team wants one fact only): keep **`Fact_StationHourBalance`** as the single fact (trips aggregated in ETL; weather attributes denormalized into `Dim_DateTime` or a wide `Dim_WeatherSnapshot`) — loses trip-level detail but stays pure Star.

**Join keys:**

- Trips ↔ Weather: `city_code` + `date_hour` (Chicago → NOAA Midway `72534014819`; NYC → Central Park `72505394728`)
- Trips ↔ Holiday: `calendar_date` + `country=US`
- Divvy ↔ Citi Bike: **not** on `station_id` (different systems) — union into conformed fact with `city_sk`

**Example aggregations:**

- `SUM(trips_ended) - SUM(trips_started)` by station × hour (rebalancing priority; dương = dồn ứ, âm = rút cạn)
- `COUNT(*)` by city × `is_holiday` × `hour_of_day`
- `AVG(trip_count)` on rainy vs. dry hours (weather join)

### 3.4 Three Datasets

| # | Dataset | Scope | Download |
|---|---------|-------|----------|
| 1 | **Divvy Trip Data (Chicago)** | Trip transactions: start/end station, timestamps, member/casual | https://divvybikes.com/system-data → S3 https://divvy-tripdata.s3.amazonaws.com/ (e.g. `202406-divvy-tripdata.zip`) — **HTTP 200 verified** |
| 2 | **Citi Bike Trip Histories (NYC)** | Same conceptual grain; different column names over years | https://citibikenyc.com/system-data → S3 https://s3.amazonaws.com/tripdata/ (e.g. `202406-citibike-tripdata.zip`) — **HTTP 200 verified** (~700 MB/month) |
| 3 | **NOAA NCEI Local Climatological Data (LCD)** | Hourly weather per city — **separate station per city** | https://www.ncei.noaa.gov/cdo-web/ and bulk https://www.ncei.noaa.gov/data/local-climatological-data/access/ |

**NOAA station mapping (verified names in CSV header):**

| City | LCD file pattern | Station name |
|------|------------------|--------------|
| Chicago (Divvy) | `72534014819.csv` | CHICAGO MIDWAY AIRPORT, IL US |
| New York (Citi Bike) | `72505394728.csv` | NY CITY CENTRAL PARK, NY US |

**Join validation (Category 2):**

| Source A | Source B | Join key | Result |
|----------|----------|----------|--------|
| Divvy trips | Citi Bike trips | `city_sk` only (union conformed fact) | **PASS** as multi-city DW — **not** station-level cross join |
| Divvy trips | NOAA Chicago LCD | `date_hour` (from `started_at`) | **PASS** |
| Citi Bike trips | NOAA NYC LCD | `date_hour` | **PASS** |
| Divvy station A | Citi Bike station B | `station_id` | **FAIL** — different ID namespaces |

**Operational notes:**

- Pick **same calendar months** in both cities (e.g. `2024-06`) for fair cross-city dashboards.
- Divvy/Citi schemas **changed over years** (column renames, dockless rows with empty station names) — good messy ETL for 3NF.
- Citi Bike monthly ZIPs are **large** (hundreds of MB); use one month for development, full history for final load demo.
- US **federal holidays** apply to both cities; load into `Dim_Holiday` for aggregation.

---

## Strict Dataset Validation Summary

Validation date: **2026-06-28**. Methods: HTTP download checks, CSV header inspection, documentation cross-check, geographic consistency review.

### Category 1 — Traffic congestion

| Criterion | Original proposal (Kaggle + UCI Air Quality + Urban Traffic Flow) | Corrected proposal (UCI + NOAA MSP + MnDOT ATR) |
|-----------|-------------------------------------------------------------------|--------------------------------------------------|
| ≥3 separate sources | ✓ | ✓ |
| Downloadable / accessible | Kaggle ✓; UCI Air ✓; Urban Flow ✗ ambiguous | UCI ✓ (UI download); NOAA ✓ (bulk CSV); MnDOT ✓ (Excel) |
| Joinable on common keys | **✗** datetime-only join **invalid** (Italy vs Minneapolis) | **✓** `date_hour` + Minneapolis geography |
| Geographic consistency | **✗** | **✓** Twin Cities / Minnesota |
| Messy data for ETL | Moderate (Kaggle clean) | **✓** NOAA wide CSV; MnDOT Excel wide format |
| Star/Snowflake/Galaxy DDS | Galaxy ✓ (3 facts + conformed dims); Cat 1 = Star | ✓ |
| Manager role + aggregation | ✓ | ✓ |
| Course guideline (avoid Kaggle-only) | **⚠** | **✓** (official sources) |
| **Overall** | **FAIL** | **PASS** |

### Category 2 — Bike-share dispatch

| Criterion | Divvy + Citi Bike + NOAA | Result |
|-----------|--------------------------|--------|
| ≥3 separate sources | ✓ | PASS |
| Downloadable | Divvy S3 ✓; Citi S3 ✓; NOAA ✓ | PASS |
| Joinable | Trips ↔ weather via `city + date_hour` ✓ | PASS |
| Cross-system station join | station_id not portable | Expected — use **conformed city dimension** |
| Multi-dataset aggregation | net station flow × weather × holiday | PASS |
| Star/Snowflake/Galaxy DDS | **Galaxy** (3 shared-dimension facts) | PASS |
| Manager role | Trưởng phòng Điều phối | PASS |
| **Overall** | | **PASS** |

---

## Recommended Priority

| Priority | Topic | Rationale |
|----------|-------|-----------|
| **1** | **Category 2 — Bike-share dispatch** | All three team-chosen sources **validated**; strong daily/weekly manager use case; rich ETL (schema drift, millions of rows, multi-city conformed dimensions); clear aggregations (station balance × weather). |
| **2** | **Category 1 — Traffic congestion (corrected datasets)** | Excellent **factor analysis** story once UCI Air Quality & Urban Traffic Flow are **replaced**; smaller data volume; good for SCD/holiday dimension and weather DQ checks. |

### Immediate team actions

1. **Drop** UCI Air Quality and generic Urban Traffic Flow from Category 1 unless you change the traffic study to **Italy** or **Glasgow** (different manager geography).
2. **Replace** Kaggle mirror with **UCI** or **MnDOT** as the cited primary source.
3. For Category 2, document **Chicago vs NYC** as two markets under one dispatch director — not one unified station network.
4. Align overlap windows: traffic **2012–2018** with NOAA `72658014922` for same years; bike **same month** across Divvy/Citi when comparing cities.

---

## GBFS, MDM & Hybrid ETL (Category 2)

*Added from team Q&A (2026-06-28).*

### What is GBFS?

**GBFS (General Bikeshare Feed Specification)** is an open JSON standard for **real-time bike-share system data**. Operators publish feeds such as:

| Feed | Typical content | DW role |
|------|-----------------|--------|
| `station_information.json` | Station ID, name, lat/lon, capacity, rental methods | **Master / dimension** (`Dim_Station`) |
| `station_status.json` | Bikes available, docks empty, station active/closed | **Operational snapshot** (rebalancing KPIs) |
| `free_bike_status.json` | Dockless bike locations (if applicable) | Optional fact / staging |

**Public URLs (examples):** Divvy and Citi Bike both link GBFS from their [system-data](https://divvybikes.com/system-data) / [system-data](https://citibikenyc.com/system-data) pages.

### Why treat GBFS as MDM + Push (not only periodic Pull)?

Per [`2_Guidelines/README.md`](../2_Guidelines/README.md): **Push for master data**, **Pull for heavy transactions**.

| | **GBFS station master (Push)** | **Monthly trip CSV (Pull)** |
|--|-------------------------------|----------------------------|
| **Data type** | Reference / master — stations, capacity, location | Transaction — rides (start/end, time, user type) |
| **Change pattern** | Stations added, moved, renamed, capacity changed **any day** | Bulk history released **monthly** |
| **Dispatch need** | Dispatcher needs **current** station list & live availability for rebalancing | Needs **historical** trip patterns for demand forecasting |
| **Risk if Pull-only** | Trip row references `station_id` **before** monthly master refresh → **late-arriving dimension**, wrong joins, skeleton stations | Less critical on a schedule if grain is historical months |

**Short reasons to use Push for GBFS (MDM):**

1. **Master data freshness** — `Dim_Station` stays aligned with operator’s live catalog (new stations, retirements, coordinate fixes).
2. **Avoid late-arriving dimensions** — trips in staging can resolve `station_sk` immediately when master was pushed first.
3. **Matches course hybrid ETL** — GBFS push + trip file pull demonstrates both patterns and supports **ETL bonus** (async master vs transaction timing).
4. **Operational vs analytic split** — GBFS `station_status` supports “which stations are empty **now**”; trip pull supports “which stations were net exporters **last week**”.

**Practical note:** GBFS is often **polled** every 1–5 minutes in production; for the project, **simulating Push** (scheduled job POSTing JSON snapshot to Hop Web Service / staging) satisfies the same architectural intent as proactive master delivery.

---

## Open Questions

1. **Single-city vs multi-city bike scope:** Is the manager responsible for **both Chicago and NYC**, or should the team pick **Divvy + NOAA Chicago only** (simpler) and use Citi Bike as a second “source system” for ETL variety only?
2. **Category 1 depth:** Is one corridor (I-94 ATR 301) enough, or must you include **multiple MnDOT stations** in the fact table from day one?
3. **Hybrid ETL (course bonus):** **Recommended:** simulate **GBFS station_information (+ optional station_status) push** into staging/MDM while **monthly trip ZIPs pull** incrementally (LSET/CET). See [GBFS, MDM & Hybrid ETL](#gbfs-mdm--hybrid-etl-category-2) above.

### Decision log (conversation notes)

| Date | Topic | Note |
|------|-------|------|
| 2026-06-28 | Dataset validation | Category 1 original trio **FAIL** (UCI Air Quality = Italy; Urban Traffic Flow ≠ Minneapolis). Category 2 Divvy + Citi + NOAA **PASS**. |
| 2026-06-28 | GBFS / MDM | GBFS = live station **master** feeds; use **Push** for MDM, **Pull** for monthly trip history; reduces late-arriving `Dim_Station` issues and fits course hybrid ETL. |
| 2026-06-28 | Scope | Traffic: Minneapolis I-94 + NOAA MSP + MnDOT ATR. Bike: multi-city via `Dim_City`; no cross-join on `station_id` between Divvy and Citi. |
| 2026-06-28 | DDS schema type | Category 2: **3 fact tables** + shared dims = **Galaxy**; `Dim_City` → `Dim_Market` is optional **snowflake** within dims. Category 1 remains **Star**. |

---

*HCMUS Master IS — Advanced Business Intelligence — Topic exploration v2 (transportation).*
