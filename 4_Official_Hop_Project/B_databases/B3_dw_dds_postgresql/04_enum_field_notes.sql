-- Enum / coded field notes (DDS star schema)

\connect dw_dds

COMMENT ON COLUMN dds.dim_city.city_code IS
    'Enum: CHI (Chicago), NYC (New York City).';

COMMENT ON COLUMN dds.dim_city.gbfs_system_id IS
    'Enum: divvy, citibike.';

COMMENT ON COLUMN dds.dim_station.station_status IS
    'Enum: open, closed, maintenance. Operational status for this SCD2 dimension row.';

COMMENT ON COLUMN dds.dim_station.row_status IS
    'Enum (SCD2): active, deleted. Filter active for current station lookup; join fact by station_sk without row_status filter for history.';

COMMENT ON COLUMN dds.dim_datetime.day_of_week IS
    'Coded range ISO 8601: 1=Monday … 7=Sunday.';

COMMENT ON COLUMN dds.dim_datetime.hour IS
    'Coded range: 0–23 (local hour).';

COMMENT ON COLUMN dds.dim_datetime.month IS
    'Coded range: 1–12.';

COMMENT ON COLUMN dds.dim_datetime.season IS
    'Enum (Northern Hemisphere, by calendar month): winter (Dec–Feb), spring (Mar–May), summer (Jun–Aug), fall (Sep–Nov). Sample 2026-01–05 uses winter, spring only.';

COMMENT ON COLUMN dds.dim_datetime.is_peak_hour IS
    'Boolean rule: TRUE on weekdays (ISO dow 1–5) at hours 7, 8, 17, 18 local; else FALSE.';

COMMENT ON COLUMN dds.dim_weather_condition.weather_category IS
    'Enum (seeded): Clear, Rain, Snow, Fog.';

COMMENT ON COLUMN dds.dim_weather_condition.precipitation_band IS
    'Enum (seeded): none, light_moderate, snow.';
