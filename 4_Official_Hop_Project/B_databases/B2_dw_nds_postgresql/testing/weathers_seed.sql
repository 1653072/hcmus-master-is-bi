-- FAKE/TEST DATA — không dùng cho production, chỉ để test pipeline NDS→DDS
\connect dw_nds

TRUNCATE TABLE nds.weather CASCADE;

INSERT INTO nds.weather (
    weather_sk,
    city_sk,
    observation_hour,
    report_type,
    temperature_c,
    precipitation_mm,
    wind_speed_ms,
    present_weather,
    weather_category
) VALUES
-- Chicago Weather (city_sk = 1)
(101, 1, '2026-02-15 08:00:00', 'FM-15', 5.50, 0.00, 3.20, 'Clear', 'Clear'),
(102, 1, '2026-02-15 14:00:00', 'FM-15', 8.00, 2.50, 5.10, 'Rain', 'Rain'),
-- NYC Weather (city_sk = 2)
(103, 2, '2026-02-15 08:00:00', 'FM-15', -2.00, 1.20, 6.00, 'Snow', 'Snow'),
(104, 2, '2026-02-15 14:00:00', 'FM-15', 1.00, 0.00, 2.50, 'Clear', 'Clear');

-- Adjust sequence
SELECT setval('nds.weather_weather_sk_seq', COALESCE((SELECT MAX(weather_sk) FROM nds.weather), 1));
