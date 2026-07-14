\connect dw_dds

-- Cities
INSERT INTO dds.dim_city (city_code, city_name, timezone, noaa_station_id, gbfs_system_id) VALUES
    ('CHI', 'Chicago', 'America/Chicago', 'USW00014819', 'divvy'),
    ('NYC', 'New York City', 'America/New_York', 'USW00094728', 'citibike');

-- Weather condition lookup (Type 1)
INSERT INTO dds.dim_weather_condition (weather_category, precipitation_band) VALUES
    ('Clear', 'none'),
    ('Rain', 'light_moderate'),
    ('Snow', 'snow'),
    ('Fog', 'none');

-- DateTime: 2026-01-01 .. 2026-05-31, every hour
-- datetime_sk = YYYYMMDDHH (e.g. 2026010114)
-- is_peak_hour: weekday hours 7-8, 17-18 local
INSERT INTO dds.dim_datetime (datetime_sk, date, hour, day_of_week, is_weekend, is_peak_hour, year, quarter, month, month_name, season)
SELECT
    (EXTRACT(YEAR FROM d)::INT * 1000000
     + EXTRACT(MONTH FROM d)::INT * 10000
     + EXTRACT(DAY FROM d)::INT * 100
     + h) AS datetime_sk,
    d::DATE AS date,
    h AS hour,
    EXTRACT(ISODOW FROM d)::SMALLINT AS day_of_week,
    EXTRACT(ISODOW FROM d) IN (6, 7) AS is_weekend,
    (EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5 AND h IN (7, 8, 17, 18)) AS is_peak_hour,
    EXTRACT(YEAR FROM d)::SMALLINT AS year,
    EXTRACT(QUARTER FROM d)::SMALLINT AS quarter,
    EXTRACT(MONTH FROM d)::SMALLINT AS month,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (12, 1, 2) THEN 'winter'
        WHEN EXTRACT(MONTH FROM d) IN (3, 4, 5) THEN 'spring'
        WHEN EXTRACT(MONTH FROM d) IN (6, 7, 8) THEN 'summer'
        ELSE 'fall'
    END AS season
FROM generate_series('2025-12-01'::DATE, '2026-06-30'::DATE, INTERVAL '1 day') AS d
CROSS JOIN generate_series(0, 23) AS h;
