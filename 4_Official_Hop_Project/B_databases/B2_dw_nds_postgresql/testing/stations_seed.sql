-- FAKE/TEST DATA — không dùng cho production, chỉ để test pipeline NDS→DDS
\connect dw_nds

TRUNCATE TABLE nds.station CASCADE;

INSERT INTO nds.station (
    station_sk,
    city_sk,
    source_station_id,
    station_name,
    latitude,
    longitude,
    capacity,
    station_status,
    effective_from,
    effective_to,
    row_status,
    is_current
) VALUES
-- Chicago Stations (city_sk = 1)
(11, 1, 'CHI10001', 'Chicago Central Station', 41.87810000, -87.62980000, 20, 'open', '2026-01-01 00:00:00', NULL, 'active', TRUE),
(12, 1, 'CHI10002', 'Chicago Loop Station', 41.88270000, -87.63240000, 15, 'open', '2026-01-01 00:00:00', NULL, 'active', TRUE),
-- NYC Stations (city_sk = 2)
(21, 2, '6602.05', 'NYC Broadway Station', 40.75890000, -73.98510000, 30, 'open', '2026-01-01 00:00:00', NULL, 'active', TRUE),
(22, 2, '5514.01', 'NYC Central Park Station', 40.78510000, -73.96830000, 25, 'open', '2026-01-01 00:00:00', NULL, 'active', TRUE);

-- Adjust sequence
SELECT setval('nds.station_station_sk_seq', COALESCE((SELECT MAX(station_sk) FROM nds.station), 1));
