\connect dw_nds

CREATE SCHEMA IF NOT EXISTS import AUTHORIZATION hop_nds_user;
ALTER SCHEMA import OWNER TO hop_nds_user;

DROP TABLE IF EXISTS import.stg_trip;

CREATE UNLOGGED TABLE import.stg_trip (
    source_city_code VARCHAR(10) NOT NULL,
    ride_id          VARCHAR(64) NOT NULL,
    rideable_type    VARCHAR(50),
    started_at       TIMESTAMP NOT NULL,
    ended_at         TIMESTAMP,
    start_station_id TEXT,
    end_station_id   TEXT,
    start_lat        NUMERIC(12, 8),
    start_lng        NUMERIC(12, 8),
    end_lat          NUMERIC(12, 8),
    end_lng          NUMERIC(12, 8),
    member_casual    VARCHAR(20),
    trip_month       CHAR(6)
);

ALTER TABLE import.stg_trip OWNER TO hop_nds_user;
GRANT USAGE ON SCHEMA import TO hop_nds_user;
GRANT SELECT, INSERT, TRUNCATE ON TABLE import.stg_trip TO hop_nds_user;
