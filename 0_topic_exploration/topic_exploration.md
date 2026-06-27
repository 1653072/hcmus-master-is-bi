# Data Warehouse Topic Exploration

Proposed data warehouse topics for the HCMUS Master IS — Advanced Business Intelligence final project.

**Alignment:** These proposals follow [`2_Guidelines/README.md`](../2_Guidelines/README.md) and [`1_Project_Requirements`](../1_Project_Requirements/) (≥3 sources, messy operational data, NDS 3NF → DDS Star/Snowflake, manager-driven analytics, aggregation/OLAP).

**Scope (team decision):** Topics are framed **globally** (multi-country datasets and ISO-based join keys). The team will **narrow regions** after a final topic is selected. **Internal simulated sources** (e.g. Docker HR/payroll like `3_Hop_ETL_Test`) are **out of scope until the topic is confirmed**.

Each topic includes:

- Exactly **one** managerial role (100% daily DW user)
- **≥3 separate, downloadable datasets** with join keys
- **Star or Snowflake** DDS (not Galaxy)
- Multi-dataset **aggregation** capability

---

## Table of Contents

1. [Category 1 — Workforce Productivity vs. Labor Compensation](#category-1--workforce-productivity-vs-labor-compensation)
2. [Category 2 — Global Recruitment Planning](#category-2--global-recruitment-planning)
3. [Category 3 — Multi-Business Conglomerate Performance](#category-3--multi-business-conglomerate-performance)
4. [Category 4 — Global Supply Chain Cost vs. Trade Performance](#category-4--global-supply-chain-cost-vs-trade-performance)
5. [Category 5 — Retail & Consumer Market Effectiveness](#category-5--retail--consumer-market-effectiveness)
6. [Category 6 — ESG / Carbon Intensity by Business & Geography](#category-6--esg--carbon-intensity-by-business--geography)
7. [Self-Validation Summary](#self-validation-summary)
8. [Recommended Priority for HCMUS DW Project](#recommended-priority-for-hcmus-dw-project)
9. [Team Decisions](#team-decisions)

---

## Category 1 — Workforce Productivity vs. Labor Compensation

### Topic Name

**Regional Workforce Productivity & Compensation Efficiency Analytics**

Evaluate achievements and performance of the workforce against income/compensation by months, cities, countries, and industries — helping the Head of People identify locations with lower cost but higher productivity and propose strategies to optimize operation cost and recruitment plans.

### 3.1 Managerial Role

**Chief People Officer (CPO) / Head of People Analytics** — owns global people cost strategy, geographic workforce footprint, and talent ROI.

### 3.2 Business Use Cases

- Compare **output per labor hour** (productivity) vs. **average wage / unit labor cost** by **month/quarter, metro, state, country**.
- Rank locations as **high-performance / lower-cost** vs. **high-cost / low-productivity** hubs.
- Support decisions on: hub consolidation, nearshore/offshore expansion, compensation band adjustments, and **recruitment prioritization by city/country**.
- Monthly/quarterly executive views: *"Where do we get the most output per compensation dollar?"*

> **Scope note:** Public data measures productivity at **industry × geography × time**, not individual employee KPIs. That is the standard DW grain for a CPO comparing **markets**, not HRIS row-level performance reviews.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

| Need | OLTP (HRIS, payroll) | Data Warehouse |
|------|----------------------|----------------|
| Cross-source metrics | Siloed; hard to blend BLS + OECD + internal payroll | Integrated **facts** with conformed dimensions |
| Time-series aggregation | Optimized for current employee transactions | Pre-modeled for **SUM/AVG by month, city, country, industry** |
| Historical comparison | Payroll resets; limited history | **SCD Type 2** on geography/industry; year-over-year slices |
| OLAP | Heavy joins on every report | **Star schema** + cube: drill country → state → metro |

**Suggested DDS (Star Schema):**

- **Fact:** `Fact_WorkforceProductivityCost` (grain: industry × geography × month)
- **Dimensions:** `Dim_Date`, `Dim_Geography` (country/state/metro), `Dim_Industry` (NAICS/ISIC bridge), `Dim_Currency` (optional)

**Join keys:** `industry_code` (NAICS ↔ ISIC bridge), `geo_code` (FIPS / ISO country / metro), `year`, `quarter`

**Example aggregations:** average wage per employee by metro × quarter; productivity index ÷ compensation index; YoY % change by country.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **BLS QCEW** | Employment, total wages, avg weekly wage by area & NAICS (quarterly) | https://www.bls.gov/cew/additional-resources/open-data/home.htm |
| 2 | **BLS Industry Productivity** | Output/hour, unit labor cost, compensation by NAICS | https://www.bls.gov/productivity/data.htm |
| 3 | **OECD Unit Labour Costs (ULC)** | Quarterly ULC by country & economic activity | https://data-explorer.oecd.org/ (dataset **ULC_QUA**) |

---

## Category 2 — Global Recruitment Planning

### Topic Name

**Global Talent Supply–Demand & Recruitment Budget Planning**

How a global corporation prepares a recruitment plan for specific roles, headcounts, budgets, cities, countries, and timestamps.

### 3.1 Managerial Role

**Director of Global Workforce Planning** — owns headcount plans, role-level hiring targets, and recruitment budgets by location and period.

### 3.2 Business Use Cases

- Plan **headcount by role (SOC)**, **city/metro/country**, and **month/quarter**.
- Estimate **budget** = planned hires × local wage benchmarks (OES) adjusted for market tightness (JOLTS, Indeed index).
- Identify **hard-to-fill roles** (high openings, low hire rate, rising postings).
- Build recruitment calendars: when/where to open reqs for Software Engineers, Sales, Operations, etc.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

Workforce planning blends **demand signals** (postings, openings), **supply signals** (hires, separations), and **cost signals** (wages)—updated at different cadences (daily postings vs. monthly JOLTS vs. annual OES). A DW:

- Stores **conformed role & geography dimensions** (SOC, NAICS, state/metro/country).
- Supports **multi-dataset aggregation**: e.g. `openings / employed × median_wage` by role × metro × month.
- Enables **scenario cubes** (best/base/worst hiring plans) without hammering operational ATS/HRIS.

**Suggested DDS (Snowflake Schema):**

- **Fact:** `Fact_RecruitmentMarket` (grain: occupation × geography × month)
- **Dimensions:** `Dim_Occupation` (SOC; snowflake to skills via O\*NET if extended), `Dim_Geography`, `Dim_Date`, `Dim_Industry`

**Join keys:** `SOC_code`, `state_code` / `metro_code` / `country_ISO`, `year_month`, `NAICS_industry_code`

**Example aggregations:** SUM(job_openings) by SOC × state × month; AVG(median_wage) × planned_headcount; posting_index trend by sector × city.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **Indeed Hiring Lab Job Postings Index** | Daily/weekly postings by sector, state, metro, country | https://github.com/hiring-lab/data and https://data.indeed.com |
| 2 | **BLS JOLTS** | Job openings, hires, quits, layoffs by industry & region (monthly) | https://download.bls.gov/pub/time.series/jt/ |
| 3 | **BLS OES** | Occupational employment & wage percentiles by metro/state | https://www.bls.gov/oes/tables.htm and https://download.bls.gov/pub/time.series/oe/ |

---

## Category 3 — Multi-Business Conglomerate Performance

### Topic Name

**Multi-Business Unit Portfolio Performance & Effectiveness Dashboard**

How a large corporation operating multiple businesses across unrelated industries monitors each business's performance, revenues, and effectiveness by time, city, country, and segment.

### 3.1 Managerial Role

**Group Chief Strategy Officer (Group CSO)** — monitors each business line's revenue, productivity, and capital efficiency across countries and time.

### 3.2 Business Use Cases

- Track **turnover, value added, employment, investment** per **business segment (NACE/ISIC)** per **country/region** per **year/quarter**.
- Compare unrelated divisions (e.g. manufacturing vs. retail vs. financial services) on common KPIs: revenue/employee, value-added margin, labor share.
- Identify underperforming units by geography; support divest/invest decisions and capital allocation.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

A conglomerate's ERPs are **per subsidiary and per industry** with different charts of accounts. The DW:

- Harmonizes **industry codes** (NACE ↔ ISIC ↔ internal BU code).
- Holds **10+ years** of structural statistics for trend and benchmark analysis.
- Delivers **one star schema** for Power BI/SSAS: slice by business × country × year without cross-ERP joins.

**Suggested DDS (Star Schema):**

- **Fact:** `Fact_BusinessUnitPerformance` (grain: business_segment × country × year)
- **Dimensions:** `Dim_BusinessSegment`, `Dim_Country`, `Dim_Date`, `Dim_SizeClass` (optional)

**Join keys:** `NACE_r2` / `ISIC_rev4` (via mapping table), `country_ISO`, `year`

**Example aggregations:** SUM(turnover) by NACE section × country × year; value_added / employment; cross-source variance checks (Eurostat vs OECD).

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **Eurostat SBS** | Turnover, value added, employment by NACE & country (`sbs_na_ind_r2`) | https://ec.europa.eu/eurostat/en/web/products-datasets/-/SBS_NA_IND_R2 and https://ec.europa.eu/eurostat/data/bulkdownload |
| 2 | **OECD STAN** | Output, VA, labor, investment by industry & country | https://www.oecd.org/en/data/datasets/structural-analysis-database.html |
| 3 | **World Bank WDI** | Macro indicators (GDP, sector value added, population) by country & year | https://data.worldbank.org/data/download/WDI_csv.zip |

---

## Category 4 — Global Supply Chain Cost vs. Trade Performance

### Topic Name

**Global Supply Chain Cost–Performance & Trade Flow Analytics**

### 3.1 Managerial Role

**VP of Global Supply Chain Operations** — daily monitoring of import/export flows, logistics quality, and landed-cost drivers by corridor and time.

### 3.2 Business Use Cases

- Monitor **import/export value & volume** by product category, partner country, and month/year.
- Correlate **logistics performance (LPI)** and **trade costs** with on-time delivery and margin by region.
- Decide sourcing shifts: which origin countries offer lower logistics friction vs. trade volume growth.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

Supply chain data spans **customs/trade**, **logistics benchmarks**, and **tariff/reference** systems. OLTP TMS/WMS handles shipments; it does **not** integrate UN/WB macro trade well. A DW:

- Enables **multi-dataset joins** on `reporter_country`, `partner_country`, `HS_chapter`, `year`.
- Supports rolling aggregations: 12-month trade sum, YoY growth, trade/GDP by corridor.
- Delivers geographic drill-down in OLAP without repeated heavy ETL at query time.

**Suggested DDS (Star Schema):**

- **Fact:** `Fact_TradeFlow` (grain: reporter × partner × product × month)
- **Dimensions:** `Dim_Country`, `Dim_Product` (HS), `Dim_Date`, `Dim_LogisticsProfile` (LPI scores by country-year)

**Join keys:** `ISO_country_code`, `year`, `HS_2digit` / product group (where available)

**Example aggregations:** SUM(export_value) by partner country × product × year; trade growth correlated with LPI score changes.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **WITS Trade Stats** | Country-level export/import summaries | https://wits.worldbank.org/datadownload.aspx |
| 2 | **UNCTADstat** | International trade time series (free CSV bulk) | https://unctadstat.unctad.org/ |
| 3 | **World Bank Logistics Performance Index (LPI)** | Logistics performance scores by country & year | https://datacatalog.worldbank.org/search/dataset/0038649/logistics-performance-index |

---

## Category 5 — Retail & Consumer Market Effectiveness

### Topic Name

**Consumer Market & Retail Sales Effectiveness Analytics**

### 3.1 Managerial Role

**Chief Marketing Officer (CMO)** — owns market performance, category growth, and marketing spend efficiency by region and period.

### 3.2 Business Use Cases

- Track **retail sales** by NAICS category × month vs. **CPI/category inflation** and **employment in retail sectors**.
- Measure "real" market growth (nominal sales minus price effect).
- Allocate marketing budget by high-growth/low-saturation categories and regions.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

Marketing needs **aligned time series** from Census (sales), BLS (prices, employment)—different release calendars and revisions. A DW:

- Stores **revision-safe history** and conformed `Dim_RetailCategory` (NAICS).
- Supports **cube aggregations**: SUM(sales), AVG(CPI_change), sales_per_employee by category × month.
- Separates analytical load from operational campaign/CRM databases.

**Suggested DDS (Snowflake Schema):**

- **Fact:** `Fact_MarketPerformance` (grain: retail_category × geography × month)
- **Dimensions:** `Dim_RetailCategory`, `Dim_Geography`, `Dim_Date`, `Dim_PriceIndex`

**Join keys:** `NAICS_code`, `year_month`, `geo_code` (US national/regional)

**Example aggregations:** SUM(retail_sales) by NAICS × month; real sales growth = nominal sales − CPI adjustment; sales per employee.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **U.S. Census MRTS** | Monthly retail & food services sales | https://www.census.gov/econ/currentdata/?programCode=MRTS and API https://api.census.gov/data/timeseries/eits/mrts |
| 2 | **BLS CPI** | Consumer price indexes by category (monthly) | https://download.bls.gov/pub/time.series/cu/ |
| 3 | **BLS CES** | Employment & hours by industry (monthly) | https://download.bls.gov/pub/time.series/ce/ |

---

## Category 6 — ESG / Carbon Intensity by Business & Geography

### Topic Name

**Corporate Carbon Intensity & Business Unit Environmental Performance**

### 3.1 Managerial Role

**Chief Sustainability Officer (CSO)** — monitors emissions footprint and intensity KPIs by business segment, state/country, and year.

### 3.2 Business Use Cases

- Report **GHG emissions** by **industry sector × state/country × year**.
- Compute **emissions per value added / per employee** when joined with structural business stats.
- Prioritize decarbonization by worst-performing business unit × geography combinations.

### 3.3 Why a Data Warehouse (Not a Normal OLTP Database)?

ESG reporting requires **multi-year, multi-source** environmental + economic denominators. OLTP environmental systems log facility-level data; they rarely hold OECD/Eurostat/EPA history in one analytical model. A DW:

- Provides unified **Fact_EmissionsPerformance** with conformed geography & industry.
- Supports aggregations for regulatory disclosures (Scope totals by country-year).
- Handles **SCD** on industry classification changes (NAICS/NACE revisions).

**Suggested DDS (Star Schema):**

- **Fact:** `Fact_EmissionsPerformance` (grain: industry × geography × year)
- **Dimensions:** `Dim_Industry`, `Dim_Geography`, `Dim_Date`, `Dim_EmissionType`

**Join keys:** `country_ISO`, `industry_sector_code`, `year`

**Example aggregations:** SUM(GHG_emissions) by sector × state × year; emissions intensity = emissions / value_added.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **EPA GHG Inventory** | State & sector greenhouse gas emissions | https://cfpub.epa.gov/ghgdata/inventoryexplorer/ and https://catalog.data.gov/dataset/2012-2022-state-level-greenhouse-gas-emission-totals-by-industry |
| 2 | **OECD GHG Footprint Indicators** | Production/demand-based emissions by industry & country | https://www.oecd.org/en/data/datasets/greenhouse-gas-footprint-indicators.html |
| 3 | **World Bank CO₂ & Energy Indicators** | Country-level CO₂ and energy statistics | https://data.worldbank.org/indicator/EN.ATM.CO2E.KT (bulk via WDI zip: https://data.worldbank.org/data/download/WDI_csv.zip) |

---

## Self-Validation Summary

| Criterion | Result |
|-----------|--------|
| Each topic has **exactly one** daily DW user | ✓ 6 distinct roles |
| **≥3 separate datasets** per topic with **download links** | ✓ 18 datasets total |
| **Joinable keys** documented | ✓ ISO/FIPS, NAICS/NACE/SOC, year/month |
| **Aggregation** across datasets | ✓ ratios, sums, YoY, cross-source KPIs |
| **Star or Snowflake DDS** (not Galaxy) | ✓ all proposals |
| Aligns with course guidelines (3 sources, messy, ETL, manager focus) | ✓ gov/open stats; FTP/SDMX/CSV parsing |
| Categories 1–3 match requested themes | ✓ compensation vs performance; recruitment; multi-BU |

---

## Recommended Priority for HCMUS DW Project

| Priority | Topic | Rationale |
|----------|-------|-----------|
| **1** | Category 2 — Recruitment planning | Strong **timestamp + role + geo** grain; fits LSET/CET incremental ETL; hybrid push (O\*NET master) + pull (BLS/Indeed) |
| **2** | Category 1 — Productivity vs compensation | Directly answers Head of People scenario; clear star schema |
| **3** | Category 3 — Multi-business portfolio | Best for **unrelated industries** narrative; Eurostat + OECD + WB |

**Practical note:** Prefer **raw government/official files** (BLS FTP, Eurostat bulk, EPA CSV) over pre-packaged Kaggle sets—they are messier (mixed codes, footnotes, revisions) and better demonstrate 3NF cleansing, upsert, and SCD per [`2_Guidelines/README.md`](../2_Guidelines/README.md).

**Global scope note:** Categories 1–2 mix US-centric sources (BLS) with international sources (OECD, Indeed country/metro files). ETL will need **conformed geography** (`Dim_Geography` with ISO country + optional US state/metro) and **industry/occupation crosswalks** (NAICS ↔ ISIC, SOC). Region filtering is applied later at implementation time.

---

## Team Decisions

| Question | Decision | Implication |
|----------|----------|-------------|
| **`1_Project_Requirements` location** | Done — requirements live in [`1_Project_Requirements`](../1_Project_Requirements/) | Topic exploration (`0_topic_exploration/`) complements formal requirements; keep both in sync when the final topic is chosen. |
| **Geographic scope** | **Global**; team scopes down regions after topic selection | Design NDS/DDS with country-level grain first; add US/EU sub-geography only where source data supports it. |
| **Internal vs. public data** | **Public datasets only for now** | No Docker-simulated HR/payroll until the final topic is confirmed; avoids premature ETL/infrastructure investment. |

---

*Generated for HCMUS Master IS — Advanced Business Intelligence Data Warehouse project.*
