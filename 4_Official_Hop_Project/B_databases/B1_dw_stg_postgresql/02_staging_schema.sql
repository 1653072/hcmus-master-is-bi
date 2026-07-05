\connect dw_staging

CREATE SCHEMA IF NOT EXISTS staging AUTHORIZATION hop_staging_user;
ALTER USER hop_staging_user SET search_path TO staging, public;

-- Trip tables mirror 14-column CSV; upsert key (source_city_code, ride_id); no batch_id
CREATE TABLE staging.stg_divvy_trips (
    ride_id              VARCHAR(64),
    rideable_type        VARCHAR(50),
    started_at           TIMESTAMP,
    ended_at             TIMESTAMP,
    start_station_name   VARCHAR(500),
    start_station_id     TEXT,
    end_station_name     VARCHAR(500),
    end_station_id       TEXT,
    start_lat            NUMERIC(12, 8),
    start_lng            NUMERIC(12, 8),
    end_lat              NUMERIC(12, 8),
    end_lng              NUMERIC(12, 8),
    member_casual        VARCHAR(20),
    source_city_code     VARCHAR(10) NOT NULL DEFAULT 'CHI',
    trip_month           CHAR(6),
    source_file          VARCHAR(500),
    loaded_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_stg_divvy_trips PRIMARY KEY (source_city_code, ride_id)
);

CREATE TABLE staging.stg_citibike_trips (
    ride_id              VARCHAR(64),
    rideable_type        VARCHAR(50),
    started_at           TIMESTAMP,
    ended_at             TIMESTAMP,
    start_station_name   VARCHAR(500),
    start_station_id     TEXT,
    end_station_name     VARCHAR(500),
    end_station_id       TEXT,
    start_lat            NUMERIC(12, 8),
    start_lng            NUMERIC(12, 8),
    end_lat              NUMERIC(12, 8),
    end_lng              NUMERIC(12, 8),
    member_casual        VARCHAR(20),
    source_city_code     VARCHAR(10) NOT NULL DEFAULT 'NYC',
    trip_month           CHAR(6),
    source_file          VARCHAR(500),
    loaded_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_stg_citibike_trips PRIMARY KEY (source_city_code, ride_id)
);

CREATE TABLE staging.stg_weather (
    source_city_code              VARCHAR(10) NOT NULL,
    noaa_station_id               VARCHAR(20) NOT NULL,
    observation_ts                TIMESTAMP NOT NULL,
    report_type                   VARCHAR(20),
    hourly_dry_bulb_temperature   NUMERIC(8, 2),
    hourly_precipitation          NUMERIC(10, 2),
    hourly_wind_speed             NUMERIC(8, 2),
    hourly_present_weather_type   VARCHAR(50),
    loaded_at                     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_stg_weather PRIMARY KEY (source_city_code, observation_ts)
);

COMMENT ON TABLE staging.stg_weather IS 'NOAA LCD v2 hourly rows; units metric (C, mm, m/s)';

CREATE TABLE staging.stg_gbfs_station (
    source_city_code     VARCHAR(10) NOT NULL,
    gbfs_station_id      TEXT,
    short_name           TEXT NOT NULL,
    station_name         VARCHAR(500),
    latitude             NUMERIC(12, 8),
    longitude            NUMERIC(12, 8),
    capacity             INTEGER,
    station_type         VARCHAR(50),
    region_id            VARCHAR(20),
    station_status       VARCHAR(30) DEFAULT 'open',
    operation            VARCHAR(10),
    loaded_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_stg_gbfs_station PRIMARY KEY (source_city_code, short_name)
);

CREATE INDEX idx_stg_divvy_started_at ON staging.stg_divvy_trips (started_at);
CREATE INDEX idx_stg_citibike_started_at ON staging.stg_citibike_trips (started_at);
CREATE INDEX idx_stg_weather_city_ts ON staging.stg_weather (source_city_code, observation_ts);

ALTER TABLE staging.stg_divvy_trips OWNER TO hop_staging_user;
ALTER TABLE staging.stg_citibike_trips OWNER TO hop_staging_user;
ALTER TABLE staging.stg_weather OWNER TO hop_staging_user;
ALTER TABLE staging.stg_gbfs_station OWNER TO hop_staging_user;
