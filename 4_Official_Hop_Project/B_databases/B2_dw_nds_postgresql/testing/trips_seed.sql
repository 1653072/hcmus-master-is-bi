-- FAKE/TEST DATA — không dùng cho production, chỉ để test pipeline NDS→DDS
\connect dw_nds

TRUNCATE TABLE nds.trip CASCADE;

INSERT INTO nds.trip (
    trip_sk,
    city_sk,
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    start_station_id,
    end_station_id,
    start_station_sk,
    end_station_sk,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    member_casual,
    duration_minutes,
    trip_month
) VALUES
-- Chicago Trips (city_sk = 1)
-- Matches observation_hour 2026-02-15 08:00:00 (Clear)
(1, 1, 'CHI_RIDE_001', 'classic_bike', '2026-02-15 08:05:00', '2026-02-15 08:20:00', 'CHI10001', 'CHI10002', 11, 12, 41.87810000, -87.62980000, 41.88270000, -87.63240000, 'member', 15.00, '202602'),
(2, 1, 'CHI_RIDE_002', 'electric_bike', '2026-02-15 08:12:00', '2026-02-15 08:35:00', 'CHI10002', 'CHI10001', 12, 11, 41.88270000, -87.63240000, 41.87810000, -87.62980000, 'casual', 23.00, '202602'),
-- Matches observation_hour 2026-02-15 14:00:00 (Rain)
(3, 1, 'CHI_RIDE_003', 'electric_bike', '2026-02-15 14:10:00', '2026-02-15 14:25:00', 'CHI10001', 'CHI10001', 11, 11, 41.87810000, -87.62980000, 41.87810000, -87.62980000, 'member', 15.00, '202602'),
(4, 1, 'CHI_RIDE_004', 'classic_bike', '2026-02-15 14:30:00', '2026-02-15 14:48:00', 'CHI10002', 'CHI10002', 12, 12, 41.88270000, -87.63240000, 41.88270000, -87.63240000, 'casual', 18.00, '202602'),

-- NYC Trips (city_sk = 2)
-- Matches observation_hour 2026-02-15 08:00:00 (Snow)
(5, 2, 'NYC_RIDE_001', 'electric_bike', '2026-02-15 08:15:00', '2026-02-15 08:30:00', '6602.05', '5514.01', 21, 22, 40.75890000, -73.98510000, 40.78510000, -73.96830000, 'member', 15.00, '202602'),
(6, 2, 'NYC_RIDE_002', 'classic_bike', '2026-02-15 08:40:00', '2026-02-15 09:05:00', '5514.01', '6602.05', 22, 21, 40.78510000, -73.96830000, 40.75890000, -73.98510000, 'casual', 25.00, '202602'),
-- Matches observation_hour 2026-02-15 14:00:00 (Clear)
(7, 2, 'NYC_RIDE_003', 'classic_bike', '2026-02-15 14:05:00', '2026-02-15 14:15:00', '6602.05', '6602.05', 21, 21, 40.75890000, -73.98510000, 40.75890000, -73.98510000, 'member', 10.00, '202602'),
(8, 2, 'NYC_RIDE_004', 'electric_bike', '2026-02-15 14:22:00', '2026-02-15 14:42:00', '5514.01', '5514.01', 22, 22, 40.78510000, -73.96830000, 40.78510000, -73.96830000, 'casual', 20.00, '202602');

-- Adjust sequence
SELECT setval('nds.trip_trip_sk_seq', COALESCE((SELECT MAX(trip_sk) FROM nds.trip), 1));
