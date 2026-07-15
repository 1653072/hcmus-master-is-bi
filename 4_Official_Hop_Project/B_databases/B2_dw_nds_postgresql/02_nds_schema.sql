\connect dw_nds

CREATE SCHEMA IF NOT EXISTS nds AUTHORIZATION hop_nds_user;
ALTER USER hop_nds_user SET search_path TO nds, public;

CREATE TABLE nds.city (
    city_sk           SERIAL PRIMARY KEY,
    city_code         VARCHAR(10) NOT NULL UNIQUE,
    city_name         VARCHAR(100) NOT NULL,
    timezone          VARCHAR(50) NOT NULL,
    noaa_station_id   VARCHAR(20) NOT NULL,
    gbfs_system_id    VARCHAR(50)
);

CREATE TABLE nds.station (
    station_sk        BIGSERIAL PRIMARY KEY,
    city_sk           INTEGER NOT NULL REFERENCES nds.city (city_sk),
    source_station_id TEXT NOT NULL,
    station_name      VARCHAR(500),
    latitude          NUMERIC(12, 8),
    longitude         NUMERIC(12, 8),
    capacity          INTEGER,
    station_status    VARCHAR(30) DEFAULT 'open',
    effective_from    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_to      TIMESTAMP,
    row_status        VARCHAR(20) NOT NULL DEFAULT 'active',
    is_current        BOOLEAN NOT NULL DEFAULT TRUE,
    loaded_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_station_city_source_effective UNIQUE (city_sk, source_station_id, effective_from)
);

CREATE INDEX idx_station_city_source ON nds.station (city_sk, source_station_id);
CREATE INDEX idx_station_current ON nds.station (city_sk, source_station_id) WHERE is_current = TRUE;

COMMENT ON COLUMN nds.station.source_station_id IS 'GBFS short_name = trip start/end_station_id; join with city_sk';

CREATE TABLE nds.calendar_day (
    calendar_day_sk   SERIAL PRIMARY KEY,
    calendar_date     DATE NOT NULL UNIQUE,
    day_of_week       SMALLINT NOT NULL,
    is_weekend        BOOLEAN NOT NULL,
    month             SMALLINT NOT NULL,
    season            VARCHAR(20) NOT NULL
);

CREATE TABLE nds.weather (
    weather_sk        BIGSERIAL PRIMARY KEY,
    city_sk           INTEGER NOT NULL REFERENCES nds.city (city_sk),
    observation_hour  TIMESTAMP NOT NULL,
    report_type       VARCHAR(20),
    temperature_c     NUMERIC(8, 2),
    precipitation_mm  NUMERIC(10, 2),
    wind_speed_ms     NUMERIC(8, 2),
    present_weather   VARCHAR(50),
    weather_category  VARCHAR(20),
    loaded_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_weather_city_hour UNIQUE (city_sk, observation_hour)
);

COMMENT ON TABLE nds.weather IS 'NOAA LCD v2 hourly; metric units';

CREATE TABLE nds.trip (
    trip_sk             BIGSERIAL PRIMARY KEY,
    city_sk             INTEGER NOT NULL REFERENCES nds.city (city_sk),
    ride_id             VARCHAR(64) NOT NULL,
    rideable_type       VARCHAR(50),
    started_at          TIMESTAMP NOT NULL,
    ended_at            TIMESTAMP,
    start_station_id    TEXT,
    end_station_id      TEXT,
    start_station_sk    BIGINT REFERENCES nds.station (station_sk),
    end_station_sk      BIGINT REFERENCES nds.station (station_sk),
    start_lat           NUMERIC(12, 8),
    start_lng           NUMERIC(12, 8),
    end_lat             NUMERIC(12, 8),
    end_lng             NUMERIC(12, 8),
    member_casual       VARCHAR(20),
    duration_minutes    NUMERIC(10, 2),
    trip_month          CHAR(6),
    loaded_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_trip_city_ride UNIQUE (city_sk, ride_id)
);

CREATE INDEX idx_trip_started_at ON nds.trip (city_sk, started_at);
CREATE INDEX idx_trip_end_station ON nds.trip (end_station_sk, ended_at);
CREATE INDEX idx_trip_start_hour ON nds.trip (city_sk, start_station_sk, DATE_TRUNC('hour', started_at));
CREATE INDEX idx_trip_end_hour ON nds.trip (city_sk, end_station_sk, DATE_TRUNC('hour', ended_at));

ALTER TABLE nds.city OWNER TO hop_nds_user;
ALTER TABLE nds.station OWNER TO hop_nds_user;
ALTER TABLE nds.calendar_day OWNER TO hop_nds_user;
ALTER TABLE nds.weather OWNER TO hop_nds_user;
ALTER TABLE nds.trip OWNER TO hop_nds_user;
