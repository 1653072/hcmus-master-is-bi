# Bike Share Executive Dashboard

Open `BikeShare_Executive_Dashboard.twb` with Tableau Desktop 2026.2 or newer.

## PostgreSQL connection

- Server: `localhost`
- Port: `5436`
- Database: `dw_dds`
- Schema: `dds`
- User: `analytics_reader_user`
- Connection mode: Live

Enter the PostgreSQL password when Tableau requests credentials. The password is intentionally not stored in this repository.

## KPI report (Chương 6)

Filled markdown from DDS (Jan–May 2026 Actual + YTD):

- [`kpi_report_2026_jan_may.md`](kpi_report_2026_jan_may.md)
- SQL: [`sql/kpi_report_actuals_2026_jan_may.sql`](sql/kpi_report_actuals_2026_jan_may.sql)
- Regenerate: `python3 scripts/generate_kpi_report.py` (requires Docker container `hcmus-bi-official-db-dw-dds-postgres`)

## Dashboard layout

The `Executive Overview` dashboard contains:

1. Total trips started
2. Total trips ended
3. Total absolute station imbalance
4. Monthly trips trend
5. Trip volume map by city

The desktop layout uses three KPI cards on the first row, then a monthly trend and city map below. The phone layout stacks the same views vertically.

## Current DDS checks

- Trips started: `15,835,991`
- Trips ended: `15,611,149`
- Absolute imbalance: `10,102,202`

These values were verified from Tableau against the live DDS connection on 2026-07-15.
