-- 1. Count rows for all tables
SELECT 'dim_city' AS table_name, COUNT(*) AS row_count FROM dds.dim_city
UNION ALL
SELECT 'dim_station', COUNT(*) FROM dds.dim_station
UNION ALL
SELECT 'dim_datetime', COUNT(*) FROM dds.dim_datetime
UNION ALL
SELECT 'dim_weather_condition', COUNT(*) FROM dds.dim_weather_condition
UNION ALL
SELECT 'fact_station_hour_balance', COUNT(*) FROM dds.fact_station_hour_balance;

-- 2. Check for NULL foreign keys in fact_station_hour_balance
SELECT * FROM dds.fact_station_hour_balance
WHERE city_sk IS NULL
   OR station_sk IS NULL
   OR datetime_sk IS NULL
   OR weather_condition_sk IS NULL;

-- 3. Sum of trips in DDS fact table (to be compared with COUNT(*) from nds.trip)
SELECT SUM(member_trip_count + casual_trip_count) AS total_trips_dds FROM dds.fact_station_hour_balance;

-- 4. Check avg_duration_member_minutes and avg_duration_casual_minutes
SELECT 
    COUNT(*) AS total_rows,
    COUNT(avg_duration_member_minutes) AS non_null_member_rows,
    COUNT(avg_duration_casual_minutes) AS non_null_casual_rows,
    MIN(avg_duration_member_minutes) AS min_member_duration,
    MAX(avg_duration_member_minutes) AS max_member_duration,
    MIN(avg_duration_casual_minutes) AS min_casual_duration,
    MAX(avg_duration_casual_minutes) AS max_casual_duration
FROM dds.fact_station_hour_balance;

-- 5. Check if net_flow matches trips_ended - trips_started
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE net_flow = (trips_ended - trips_started)) AS matching_rows,
    COUNT(*) FILTER (WHERE net_flow <> (trips_ended - trips_started)) AS mismatching_rows
FROM dds.fact_station_hour_balance;

-- 6. Preview 10 rows of fact_station_hour_balance
SELECT * FROM dds.fact_station_hour_balance LIMIT 10;

-- 7. Check dim_station is_current counts (to be compared with unique stations in nds.station)
SELECT COUNT(*) AS active_dim_stations FROM dds.dim_station WHERE is_current = TRUE;
