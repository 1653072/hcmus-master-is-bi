-- Enum / coded field notes (NDS 3NF)

\connect dw_nds

COMMENT ON COLUMN nds.city.city_code IS
    'Enum: CHI (Chicago), NYC (New York City).';

COMMENT ON COLUMN nds.city.gbfs_system_id IS
    'Enum: divvy, citibike. GBFS system identifier per city.';

COMMENT ON COLUMN nds.station.station_status IS
    'Enum: open, closed, maintenance. Operational status for this SCD2 version (from GBFS / MDM).';

COMMENT ON COLUMN nds.station.row_status IS
    'Enum (SCD2): active, deleted. Use active + is_current=TRUE for current master; deleted rows kept for historical fact FKs.';

COMMENT ON COLUMN nds.calendar_day.day_of_week IS
    'Coded range ISO 8601: 1=Monday … 7=Sunday (EXTRACT(ISODOW)).';

COMMENT ON COLUMN nds.calendar_day.season IS
    'Enum (Northern Hemisphere, by calendar month): winter (Dec–Feb), spring (Mar–May), summer (Jun–Aug), fall (Sep–Nov). Sample 2026-01–05 uses winter, spring only.';

COMMENT ON COLUMN nds.weather.report_type IS
    'Enum (NOAA LCD v2): FM-15 (preferred hourly), FM-16, FM-12. Exclude SOD, SOM for hourly grain.';

COMMENT ON COLUMN nds.weather.weather_category IS
    'Enum (ETL rule → Dim_WeatherCondition): Clear, Rain, Snow, Fog.';

COMMENT ON COLUMN nds.trip.rideable_type IS
    'Enum: classic_bike, electric_bike.';

COMMENT ON COLUMN nds.trip.member_casual IS
    'Enum: member, casual.';
