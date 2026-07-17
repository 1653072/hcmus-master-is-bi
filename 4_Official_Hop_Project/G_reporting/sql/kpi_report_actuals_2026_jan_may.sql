-- KPI report Actuals: Jan–May 2026 + YTD (same window recomputed)
-- Thresholds: serious abs_imbalance >= 4; prolonged depletion >6 hours net_flow < 0 per station-day
-- Output columns: kpi_code | kpi_name | period | city_code | actual_value
-- period: '1'..'5' (month) or 'YTD'

WITH base AS (
    SELECT
        f.station_sk,
        f.datetime_sk,
        f.abs_imbalance,
        f.net_flow,
        f.trips_started,
        f.member_trip_count,
        f.casual_trip_count,
        f.electric_trip_count,
        f.classic_trip_count,
        dt.date,
        dt.month,
        dt.is_peak_hour,
        c.city_code,
        w.weather_category
    FROM dds.fact_station_hour_balance f
    JOIN dds.dim_datetime dt ON dt.datetime_sk = f.datetime_sk
    JOIN dds.dim_station s ON s.station_sk = f.station_sk
    JOIN dds.dim_city c ON c.city_sk = s.city_sk
    JOIN dds.dim_weather_condition w ON w.weather_condition_sk = f.weather_condition_sk
    WHERE dt.year = 2026
      AND dt.month BETWEEN 1 AND 5
),

-- A: AVG(abs_imbalance)
kpi_a AS (
    SELECT 'A' AS kpi_code,
           'Mức mất cân bằng xe trung bình mỗi trạm/giờ (AVG abs_imbalance)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           AVG(abs_imbalance)::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'A', 'Mức mất cân bằng xe trung bình mỗi trạm/giờ (AVG abs_imbalance)', 'YTD', NULL,
           AVG(abs_imbalance)::DOUBLE PRECISION
    FROM base
),

-- B: % serious imbalance
kpi_b AS (
    SELECT 'B' AS kpi_code,
           'Tỷ lệ station-hour mất cân bằng nghiêm trọng (abs_imbalance ≥ 4)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (100.0 * COUNT(*) FILTER (WHERE abs_imbalance >= 4) / NULLIF(COUNT(*), 0))::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'B', 'Tỷ lệ station-hour mất cân bằng nghiêm trọng (abs_imbalance ≥ 4)', 'YTD', NULL,
           (100.0 * COUNT(*) FILTER (WHERE abs_imbalance >= 4) / NULLIF(COUNT(*), 0))::DOUBLE PRECISION
    FROM base
),

-- C: station-days with >6 depleted hours
depleted_station_days AS (
    SELECT
        station_sk,
        date,
        month,
        COUNT(*) FILTER (WHERE net_flow < 0) AS depleted_hours
    FROM base
    GROUP BY station_sk, date, month
    HAVING COUNT(*) FILTER (WHERE net_flow < 0) > 6
),
kpi_c AS (
    SELECT 'C' AS kpi_code,
           'Số lần trạm–ngày rút cạn kéo dài hơn 6 tiếng (net_flow < 0)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           COUNT(*)::DOUBLE PRECISION AS actual_value
    FROM depleted_station_days
    GROUP BY month
    UNION ALL
    SELECT 'C', 'Số lần trạm–ngày rút cạn kéo dài hơn 6 tiếng (net_flow < 0)', 'YTD', NULL,
           COUNT(*)::DOUBLE PRECISION
    FROM depleted_station_days
),

-- D: peak / off-peak avg imbalance
kpi_d AS (
    SELECT 'D' AS kpi_code,
           'Mức mất cân bằng giờ cao điểm (07:00–08:00 và 17:00–18:00 vào ngày thường) so với giờ thường' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (
               AVG(abs_imbalance) FILTER (WHERE is_peak_hour)
               / NULLIF(AVG(abs_imbalance) FILTER (WHERE NOT is_peak_hour), 0)
           )::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'D', 'Mức mất cân bằng giờ cao điểm (07:00–08:00 và 17:00–18:00 vào ngày thường) so với giờ thường', 'YTD', NULL,
           (
               AVG(abs_imbalance) FILTER (WHERE is_peak_hour)
               / NULLIF(AVG(abs_imbalance) FILTER (WHERE NOT is_peak_hour), 0)
           )::DOUBLE PRECISION
    FROM base
),

-- E: |CHI - NYC| avg imbalance
kpi_e AS (
    SELECT 'E' AS kpi_code,
           'Chênh lệch mất cân bằng trung bình giữa Chicago và New York (|AVG_CHI − AVG_NYC|)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           ABS(
               AVG(abs_imbalance) FILTER (WHERE city_code = 'CHI')
               - AVG(abs_imbalance) FILTER (WHERE city_code = 'NYC')
           )::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'E', 'Chênh lệch mất cân bằng trung bình giữa Chicago và New York (|AVG_CHI − AVG_NYC|)', 'YTD', NULL,
           ABS(
               AVG(abs_imbalance) FILTER (WHERE city_code = 'CHI')
               - AVG(abs_imbalance) FILTER (WHERE city_code = 'NYC')
           )::DOUBLE PRECISION
    FROM base
),

-- F: rain - clear avg imbalance
kpi_f AS (
    SELECT 'F' AS kpi_code,
           'Chênh lệch mất cân bằng khi trời mưa so với trời quang (AVG_Rain − AVG_Clear)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (
               AVG(abs_imbalance) FILTER (WHERE weather_category = 'Rain')
               - AVG(abs_imbalance) FILTER (WHERE weather_category = 'Clear')
           )::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'F', 'Chênh lệch mất cân bằng khi trời mưa so với trời quang (AVG_Rain − AVG_Clear)', 'YTD', NULL,
           (
               AVG(abs_imbalance) FILTER (WHERE weather_category = 'Rain')
               - AVG(abs_imbalance) FILTER (WHERE weather_category = 'Clear')
           )::DOUBLE PRECISION
    FROM base
),

-- G: avg trips_started per station-hour
kpi_g AS (
    SELECT 'G' AS kpi_code,
           'Số chuyến đi bắt đầu trung bình mỗi trạm/giờ (AVG trips_started)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (SUM(trips_started) * 1.0 / NULLIF(COUNT(*), 0))::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'G', 'Số chuyến đi bắt đầu trung bình mỗi trạm/giờ (AVG trips_started)', 'YTD', NULL,
           (SUM(trips_started) * 1.0 / NULLIF(COUNT(*), 0))::DOUBLE PRECISION
    FROM base
),

-- H: member / casual
kpi_h AS (
    SELECT 'H' AS kpi_code,
           'Tỷ lệ chuyến đi Member/Casual (SUM member ÷ SUM casual)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (SUM(member_trip_count) * 1.0 / NULLIF(SUM(casual_trip_count), 0))::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'H', 'Tỷ lệ chuyến đi Member/Casual (SUM member ÷ SUM casual)', 'YTD', NULL,
           (SUM(member_trip_count) * 1.0 / NULLIF(SUM(casual_trip_count), 0))::DOUBLE PRECISION
    FROM base
),

-- I: electric share %
kpi_i AS (
    SELECT 'I' AS kpi_code,
           'Tỷ lệ sử dụng xe điện trên tổng chuyến classic + electric' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (
               100.0 * SUM(electric_trip_count)
               / NULLIF(SUM(electric_trip_count) + SUM(classic_trip_count), 0)
           )::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'I', 'Tỷ lệ sử dụng xe điện trên tổng chuyến classic + electric', 'YTD', NULL,
           (
               100.0 * SUM(electric_trip_count)
               / NULLIF(SUM(electric_trip_count) + SUM(classic_trip_count), 0)
           )::DOUBLE PRECISION
    FROM base
),

-- J: demand drop when wet (Rain+Snow) vs Clear
kpi_j AS (
    SELECT 'J' AS kpi_code,
           'Mức sụt giảm nhu cầu khi mưa/tuyết so với trời quang (% giảm AVG trips_started)' AS kpi_name,
           month::TEXT AS period,
           NULL::TEXT AS city_code,
           (
               (
                   AVG(trips_started) FILTER (WHERE weather_category = 'Clear')
                   - AVG(trips_started) FILTER (WHERE weather_category IN ('Rain', 'Snow'))
               )
               / NULLIF(AVG(trips_started) FILTER (WHERE weather_category = 'Clear'), 0)
               * 100.0
           )::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month
    UNION ALL
    SELECT 'J', 'Mức sụt giảm nhu cầu khi mưa/tuyết so với trời quang (% giảm AVG trips_started)', 'YTD', NULL,
           (
               (
                   AVG(trips_started) FILTER (WHERE weather_category = 'Clear')
                   - AVG(trips_started) FILTER (WHERE weather_category IN ('Rain', 'Snow'))
               )
               / NULLIF(AVG(trips_started) FILTER (WHERE weather_category = 'Clear'), 0)
               * 100.0
           )::DOUBLE PRECISION
    FROM base
),

-- K: trips by city
kpi_k AS (
    SELECT 'K' AS kpi_code,
           'Tổng số chuyến đi bắt đầu theo thành phố (CHI / NYC)' AS kpi_name,
           month::TEXT AS period,
           city_code,
           SUM(trips_started)::DOUBLE PRECISION AS actual_value
    FROM base
    GROUP BY month, city_code
    UNION ALL
    SELECT 'K', 'Tổng số chuyến đi bắt đầu theo thành phố (CHI / NYC)', 'YTD', city_code,
           SUM(trips_started)::DOUBLE PRECISION
    FROM base
    GROUP BY city_code
)

SELECT kpi_code, kpi_name, period, city_code, actual_value
FROM (
    SELECT kpi_code, kpi_name, period, city_code, actual_value FROM kpi_a
    UNION ALL SELECT * FROM kpi_b
    UNION ALL SELECT * FROM kpi_c
    UNION ALL SELECT * FROM kpi_d
    UNION ALL SELECT * FROM kpi_e
    UNION ALL SELECT * FROM kpi_f
    UNION ALL SELECT * FROM kpi_g
    UNION ALL SELECT * FROM kpi_h
    UNION ALL SELECT * FROM kpi_i
    UNION ALL SELECT * FROM kpi_j
    UNION ALL SELECT * FROM kpi_k
) u
ORDER BY kpi_code,
         CASE WHEN period = 'YTD' THEN 99 ELSE period::INT END,
         city_code NULLS FIRST;
