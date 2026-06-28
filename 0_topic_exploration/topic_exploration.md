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
7. [Strict Dataset Validation](#strict-dataset-validation)
8. [Self-Validation Summary](#self-validation-summary)
9. [Recommended Priority for HCMUS DW Project](#recommended-priority-for-hcmus-dw-project)
10. [Team Decisions](#team-decisions)

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

> **Validation verdict: FAIL (not recommended as-is)** — See [Strict Dataset Validation — Category 2](#category-2--global-recruitment-planning-1).

### Topic Name

**Global Talent Supply–Demand & Recruitment Budget Planning** *(original proposal — requires major rescoping)*

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

**Join keys (original claim — overstated):** `SOC_code`, `state_code` / `metro_code` / `country_ISO`, `year_month`, `NAICS_industry_code`

**Example aggregations (original claim — partially invalid):** ~~SUM(job_openings) by SOC × state × month~~ — JOLTS openings are not by SOC; Indeed is an index not a count. Feasible only after bridge tables and grain harmonization.

### 3.4 Three Datasets

| # | Dataset | Description | Download |
|---|---------|-------------|----------|
| 1 | **Indeed Hiring Lab Job Postings Index** | Daily **index** (% change vs 2020-02-01 baseline), by Indeed proprietary sector / US state / US metro / country | https://github.com/hiring-lab/job_postings_tracker and https://data.indeed.com |
| 2 | **BLS JOLTS** | Job openings, hires, quits by **NAICS industry** & **US region** (monthly); **not by occupation** | https://download.bls.gov/pub/time.series/jt/ |
| 3 | **BLS OES** | Occupational employment & wages by **SOC** & US metro/state (**annual**) | https://www.bls.gov/oes/tables.htm and https://download.bls.gov/pub/time.series/oe/ |

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

## Strict Dataset Validation

Validation date: 2026-06-28. Checks: download accessibility, geographic scope vs team **global** decision, metric semantics, join-key compatibility, time grain, and fit for a course **data warehouse** (multi-source integration + aggregation), not a one-off Excel analysis.

**Legend:** PASS = feasible with documented ETL bridges | PARTIAL = usable but major caveats | FAIL = blocks topic as proposed

### Category 1 — Workforce Productivity vs. Labor Compensation

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| BLS QCEW | PASS (open CSV API) | **US only** (county/state/national) | Quarterly; employment, wages; **NAICS** | Joins to BLS Productivity on **NAICS + time** | PASS |
| BLS Industry Productivity | PASS (tables/FTP) | **US only**; mostly **national** industry, limited state | Annual; output/hour, unit labor cost; **NAICS** | **No metro/city grain** — cannot join QCEW at city level without allocating national productivity down (modeling, not source join) | PARTIAL |
| OECD ULC | PASS (OECD Data Explorer) | **Global** (OECD countries) | Quarterly; unit labour cost; **ISIC** activity | Joins to QCEW only via **US aggregate** + **NAICS↔ISIC crosswalk** — not same geography depth | PARTIAL |

**Topic verdict: PARTIAL.** Downloadable and joinable at **country × industry** or **US state × industry** with bridge tables. **Not truly global at city grain.** Original claim “metro productivity vs compensation” is **not directly supported** by BLS Productivity data.

**To pass globally:** Replace US-only leg with **Eurostat labour cost + productivity** or scope topic explicitly to **US regions** until internal/global payroll is added later.

---

### Category 2 — Global Recruitment Planning

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| Indeed Hiring Lab Index | PASS (GitHub CSV) | **11 country folders** (AU, CA, DE, EA, ES, FR, GB, IE, IT, NL, US) — not worldwide; sub-national only **US / CA / UK** | **Daily index** = % change in seasonally adjusted postings since **2020-02-01** (baseline 100). **Not absolute job counts.** Sectors = **Indeed proprietary labels** (e.g. “Accounting”), not SOC/NAICS | Cannot direct-join JOLTS or OES | FAIL (metric + taxonomy) |
| BLS JOLTS | PASS (FTP; bot-restricted — use browser/BLS tools) | **US only** | **Monthly**; openings/hires in **levels** but by **NAICS supersector** (~17–24 industry groups). **No occupation.** Regional = 4 US regions only at total nonfarm | Join to OES only via **SOC↔NAICS bridge** (e.g. BLS National Employment Matrix) — **approximate, many-to-many** | PARTIAL |
| BLS OES | PASS | **US only** | **Annual**; employment & wages by **SOC** + metro/state | Join to JOLTS via NAICS bridge; join to Indeed requires **manual Indeed-sector→SOC/NAICS mapping** (non-standard, lossy) | PARTIAL |

**Cross-dataset join matrix (Category 2):**

|  | OES (SOC + geo) | JOLTS (NAICS + US region) | Indeed (index + Indeed sector) |
|--|-----------------|---------------------------|--------------------------------|
| **OES** | — | Bridge: BLS National Employment Matrix (SOC×NAICS); geo: state/metro ≠ JOLTS 4 regions | No official crosswalk; custom mapping + **index ≠ count** |
| **JOLTS** | Bridge only | — | Industry vs Indeed sector; **monthly levels vs daily index** |
| **Indeed** | Custom mapping only | Custom mapping only | — |

**Time-grain mismatch:** Indeed = daily; JOLTS = monthly; OES = **annual**.

**Colleague feedback on Category 2:**

| Feedback | Valid? | Detail |
|----------|--------|--------|
| Data mainly US → not global; at best US regions | **Yes** | JOLTS + OES are 100% US. Indeed adds ~11 countries at country/sector index level only. |
| Indeed is % change since Feb 2020, not job counts | **Yes** | Confirmed in [Indeed README](https://github.com/hiring-lab/job_postings_tracker/blob/master/README.md): `indeed_job_postings_index` = % change vs 2020-02-01. |
| JOLTS & Indeed cannot directly join OES (industry vs SOC) | **Yes** | [BLS JOLTS FAQ](https://www.bls.gov/jlt/jltdata.htm): no occupation dimension. OES is SOC. JOLTS/Indeed are industry/sector. Requires **bridge tables**; joins are **not 1:1**. |
| External labor market survey ≠ need for warehouse | **Partially valid** | For **external-only** public stats, a DW is still used in practice (benchmarking cubes), but for **this course** the narrative is weak without **internal** facts (planned headcount, budget, reqs, hires). Team already deferred internal Docker data — Category 2 lacks a compelling internal transaction/master layer. |

**Topic verdict: FAIL as proposed.** Rename/rescope to **“US Regional Labor Market Benchmarking”** or add **internal workforce plan + ATS/payroll** sources before calling it “recruitment planning DW.”

**If team still wants recruitment angle:** minimum viable dataset swap — replace Indeed with **BLS Job Openings by state (experimental)** or use **O\*NET + OES + JOLTS** at **NAICS grain only** (drop SOC-level role planning), US-only.

---

### Category 3 — Multi-Business Conglomerate Performance

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| Eurostat SBS (`sbs_na_ind_r2`) | PASS (API/bulk SDMX-CSV tested) | **EU countries** | Annual; turnover, VA, employment; **NACE Rev.2** | Join OECD STAN via **NACE↔ISIC** + `country_ISO` + `year` | PASS |
| OECD STAN | PASS (OECD portal) | **OECD countries** | Annual; output, VA, labour; **ISIC** | Standard crosswalk to NACE | PASS |
| World Bank WDI | PASS (indicator pages; bulk zip URL may change — use [data portal](https://data.worldbank.org/) export) | **Global** | Annual; macro & sector indicators | Join on `country_ISO` + `year`; industry detail weaker than SBS/STAN | PASS |

**Topic verdict: PASS (best global topic).** Aligns with team global scope. ETL complexity is **classification crosswalks**, not impossible taxonomy gaps.

---

### Category 4 — Global Supply Chain Cost vs. Trade Performance

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| WITS Trade Stats | PASS (zip downloads on datadownload page) | **Global** (country summaries) | Mostly **annual** country aggregates | Join UNCTAD on `country_ISO` + `year` + product code where aligned | PARTIAL |
| UNCTADstat | PASS (free CSV bulk) | **Global** | Trade time series; varies by table | Compatible with WITS at country-year; HS detail varies | PASS |
| World Bank LPI | PASS (DataBank CSV export) | **Global** | **Sparse years** (survey-based index 1–5, not monthly) | Join on `country_ISO` + `year` only — **no product dimension** | PARTIAL |

**Topic verdict: PARTIAL.** Good global trade story; **LPI time grain** (multi-year) limits “daily monitoring” use case. Feasible DW with `Fact_TradeAnnual` + `Dim_LogisticsCountryYear`.

---

### Category 5 — Retail & Consumer Market Effectiveness

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| Census MRTS | PASS (API + Excel) | **US only** | Monthly retail sales; **NAICS-based categories** | Joins BLS CPI/CES on **time + industry category** | PASS (US) |
| BLS CPI | PASS (FTP) | **US only** | Monthly price indexes by category | CES/MRTS alignment via BLS category mapping | PASS (US) |
| BLS CES | PASS (FTP) | **US only** | Monthly employment/hours; **NAICS** | Strong join to MRTS | PASS (US) |

**Topic verdict: PASS for US scope; FAIL vs team global decision** unless replaced with **Eurostat retail trade** or similar EU/global retail series.

---

### Category 6 — ESG / Carbon Intensity

| Dataset | Accessible | Scope | Grain / metric | Join compatibility | Verdict |
|---------|------------|-------|----------------|-------------------|---------|
| EPA GHG Inventory | PASS (CSV export) | **US states** | Annual; emissions by **sector** | US-only; join OECD via **US country code + sector bridge** | PARTIAL |
| OECD GHG footprint | PASS | **Global** (~76 economies) | Annual; by **industry** | Joins Eurostat/SBS on `country` + `industry` + `year` | PASS |
| World Bank CO₂ indicators | PASS | **Global** | Annual; **country-level** (no industry split in basic series) | Denominator only unless paired with SBS/STAN | PARTIAL |

**Topic verdict: PARTIAL.** Strongest path: **OECD GHG + Eurostat SBS + OECD STAN** for global industry intensity; use EPA as optional US drill-down, not core join.

---

## Self-Validation Summary

| Criterion | Result (after strict validation) |
|-----------|-----------------------------------|
| Each topic has **exactly one** daily DW user | ✓ 6 distinct roles |
| **≥3 separate datasets** with **download links** | ✓ links valid; some BLS FTP requires non-bot access |
| **Joinable keys** without heavy bridges | ✗ **Category 2 FAIL**; Cat 1, 4, 6 need bridges or rescooping |
| **Global scope** (team decision) | ✓ Cat 3 best; ✗ Cat 2, 5 predominantly US; Cat 1 mixed |
| **Aggregation** across datasets | ✓ Cat 3, 5 (US); ⚠ Cat 2 aggregates mislead if treating Indeed index as counts |
| **Star or Snowflake DDS** | ✓ all proposals structurally valid |
| **Course DW fit** (multi-source ETL, not single Excel) | ✓ Cat 3, 5; ⚠ Cat 2 external-only weak |

---

## Recommended Priority for HCMUS DW Project

| Priority | Topic | Rationale (updated after validation) |
|----------|-------|--------------------------------------|
| **1** | Category 3 — Multi-business portfolio | **Only topic with clean global join path** (NACE/ISIC + country + year); all three sources validated |
| **2** | Category 1 — Productivity vs compensation | Strong HR narrative; rescope to **country/industry** or **US state** — drop unsupported city-level productivity |
| **3** | Category 6 — ESG carbon intensity | Global if built on OECD + Eurostat; drop or demote EPA to US optional layer |
| **—** | Category 5 — Retail/marketing | Good **US** ETL exercise; poor fit if team insists global |
| **—** | Category 4 — Supply chain | Viable; sparse LPI years — good for annual cube, not daily ops |
| **✗ Avoid** | Category 2 — Recruitment (original) | **Colleague feedback confirmed** — US-centric, index≠count, SOC/NAICS/Indeed mismatch, weak DW case without internal data |

**Practical note:** Prefer **raw government/official files** (BLS FTP, Eurostat bulk, EPA CSV) over pre-packaged Kaggle sets—they are messier (mixed codes, footnotes, revisions) and better demonstrate 3NF cleansing, upsert, and SCD per [`2_Guidelines/README.md`](../2_Guidelines/README.md).

**Global scope note (revised):** Category 2 and 5 are **not global** with proposed datasets. Category 1 is **US-heavy** unless OECD/Eurostat legs dominate. Implement **`Dim_Geography`** at ISO country first; add US state/metro only where sources allow.

---

## Team Decisions

| Question | Decision | Implication |
|----------|----------|-------------|
| **`1_Project_Requirements` location** | Done — requirements live in [`1_Project_Requirements`](../1_Project_Requirements/) | Topic exploration (`0_topic_exploration/`) complements formal requirements; keep both in sync when the final topic is chosen. |
| **Geographic scope** | **Global**; team scopes down regions after topic selection | Design NDS/DDS with country-level grain first; add US/EU sub-geography only where source data supports it. |
| **Internal vs. public data** | **Public datasets only for now** | No Docker-simulated HR/payroll until the final topic is confirmed; avoids premature ETL/infrastructure investment. |

---

*Generated for HCMUS Master IS — Advanced Business Intelligence Data Warehouse project.*
