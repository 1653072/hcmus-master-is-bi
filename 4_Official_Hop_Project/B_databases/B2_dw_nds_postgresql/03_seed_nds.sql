\connect dw_nds

INSERT INTO nds.city (city_code, city_name, timezone, noaa_station_id, gbfs_system_id) VALUES
    ('CHI', 'Chicago', 'America/Chicago', 'USW00014819', 'divvy'),
    ('NYC', 'New York City', 'America/New_York', 'USW00094728', 'citibike');

INSERT INTO nds.calendar_day (calendar_date, day_of_week, is_weekend, month, season)
SELECT
    d::DATE,
    EXTRACT(ISODOW FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d) IN (6, 7),
    EXTRACT(MONTH FROM d)::SMALLINT,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (12, 1, 2) THEN 'winter'
        WHEN EXTRACT(MONTH FROM d) IN (3, 4, 5) THEN 'spring'
        WHEN EXTRACT(MONTH FROM d) IN (6, 7, 8) THEN 'summer'
        ELSE 'fall'
    END
FROM generate_series('2026-01-01'::DATE, '2026-05-31'::DATE, INTERVAL '1 day') AS d;
