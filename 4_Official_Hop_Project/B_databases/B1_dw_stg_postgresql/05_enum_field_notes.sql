-- Enum / coded field notes (staging + control + metadata)
-- Valid values documented for ETL validation and reporting; VARCHAR columns (no PG ENUM type).

\connect dw_staging

COMMENT ON COLUMN staging.stg_divvy_trips.source_city_code IS
    'Enum: CHI (Chicago Divvy). Must match nds.city / dds.dim_city.city_code.';

COMMENT ON COLUMN staging.stg_divvy_trips.rideable_type IS
    'Enum (source CSV): classic_bike, electric_bike. Map electric → fact.electric_trip_count; classic → classic_trip_count.';

COMMENT ON COLUMN staging.stg_divvy_trips.member_casual IS
    'Enum (source CSV): member, casual.';

COMMENT ON COLUMN staging.stg_citibike_trips.source_city_code IS
    'Enum: NYC (Citi Bike). Must match nds.city / dds.dim_city.city_code.';

COMMENT ON COLUMN staging.stg_citibike_trips.rideable_type IS
    'Enum (source CSV): classic_bike, electric_bike.';

COMMENT ON COLUMN staging.stg_citibike_trips.member_casual IS
    'Enum (source CSV): member, casual.';

COMMENT ON COLUMN staging.stg_weather.source_city_code IS
    'Enum: CHI, NYC. Join NOAA file to city; CHI ↔ USW00014819, NYC ↔ USW00094728.';

COMMENT ON COLUMN staging.stg_weather.report_type IS
    'Enum (NOAA LCD v2 REPORT_TYPE). Hourly ETL: FM-15 (preferred), FM-16, FM-12. Exclude grain-day/month: SOD, SOM.';

COMMENT ON COLUMN staging.stg_gbfs_station.source_city_code IS
    'Enum: CHI, NYC.';

COMMENT ON COLUMN staging.stg_gbfs_station.station_type IS
    'Enum (GBFS station_information, optional): classic, e_bike. Divvy feed may omit; store NULL if absent.';

COMMENT ON COLUMN staging.stg_gbfs_station.station_status IS
    'Enum (DW normalized from GBFS station_status / MDM): open, closed, maintenance. Default open when unknown.';

COMMENT ON COLUMN staging.stg_gbfs_station.operation IS
    'Enum (MDM push): INSERT, UPDATE, DELETE. Must be in HOP_MDM_ALLOWED_OPERATIONS.';

\connect dw_control

COMMENT ON COLUMN control.etl_extraction_control.source_name IS
    'Enum (seeded sources): divvy_trips, citibike_trips, noaa_lcd, gbfs_station.';

COMMENT ON COLUMN control.etl_extraction_control.last_run_status IS
    'Enum: SUCCESS, FAILED, RUNNING, SKIPPED.';

COMMENT ON COLUMN control.etl_job_log.status IS
    'Enum: SUCCESS, FAILED, RUNNING, SKIPPED.';

\connect dw_metadata

COMMENT ON COLUMN metadata.source_registry.source_type IS
    'Enum: s3_csv (trip ZIP pull), file_pull (NOAA LCD), json_push (GBFS MDM).';
