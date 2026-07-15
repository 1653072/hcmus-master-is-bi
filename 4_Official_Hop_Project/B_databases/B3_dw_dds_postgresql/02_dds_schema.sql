\connect dw_dds

CREATE SCHEMA IF NOT EXISTS dds AUTHORIZATION hop_dds_user;
ALTER USER hop_dds_user SET search_path TO dds, public;
ALTER USER analytics_reader_user SET search_path TO dds, public;

CREATE TABLE dds.dim_city (
    city_sk           SERIAL PRIMARY KEY,
    city_code         VARCHAR(10) NOT NULL UNIQUE,
    city_name         VARCHAR(100) NOT NULL,
    timezone          VARCHAR(50) NOT NULL,
    noaa_station_id   VARCHAR(20) NOT NULL,
    gbfs_system_id    VARCHAR(50)
);

CREATE TABLE dds.dim_station (
    station_sk        BIGSERIAL PRIMARY KEY,
    city_sk           INTEGER NOT NULL REFERENCES dds.dim_city (city_sk),
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
    version           INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_dim_station_lookup ON dds.dim_station (city_sk, source_station_id) WHERE row_status = 'active';

CREATE TABLE dds.dim_datetime (
    datetime_sk       INTEGER PRIMARY KEY,
    date              DATE NOT NULL,
    hour              SMALLINT NOT NULL CHECK (hour BETWEEN 0 AND 23),
    day_of_week       SMALLINT NOT NULL,
    is_weekend        BOOLEAN NOT NULL,
    is_peak_hour      BOOLEAN NOT NULL,
    year              SMALLINT NOT NULL,
    quarter           SMALLINT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month             SMALLINT NOT NULL,
    month_name        VARCHAR(20) NOT NULL,
    season            VARCHAR(20) NOT NULL,
    CONSTRAINT uq_dim_datetime_date_hour UNIQUE (date, hour)
);

CREATE TABLE dds.dim_weather_condition (
    weather_condition_sk  SERIAL PRIMARY KEY,
    weather_category      VARCHAR(20) NOT NULL UNIQUE,
    precipitation_band    VARCHAR(30)
);

CREATE TABLE dds.fact_station_hour_balance (
    station_hour_balance_sk  BIGSERIAL PRIMARY KEY,
    station_sk               BIGINT NOT NULL REFERENCES dds.dim_station (station_sk),
    datetime_sk              INTEGER NOT NULL REFERENCES dds.dim_datetime (datetime_sk),
    weather_condition_sk     INTEGER NOT NULL REFERENCES dds.dim_weather_condition (weather_condition_sk),
    trips_started            INTEGER NOT NULL DEFAULT 0,
    trips_ended              INTEGER NOT NULL DEFAULT 0,
    net_flow                 INTEGER NOT NULL DEFAULT 0,
    abs_imbalance            INTEGER NOT NULL DEFAULT 0,
    member_trip_count        INTEGER NOT NULL DEFAULT 0,
    casual_trip_count        INTEGER NOT NULL DEFAULT 0,
    electric_trip_count      INTEGER NOT NULL DEFAULT 0,
    classic_trip_count       INTEGER NOT NULL DEFAULT 0,
    avg_duration_member_minutes NUMERIC(10, 2),
    avg_duration_casual_minutes NUMERIC(10, 2),
    temperature              NUMERIC(8, 2),
    precipitation            NUMERIC(10, 2),
    wind_speed               NUMERIC(8, 2),
    loaded_at                TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fact_grain UNIQUE (station_sk, datetime_sk)
);

CREATE INDEX idx_fact_datetime ON dds.fact_station_hour_balance (datetime_sk);
CREATE INDEX idx_fact_station ON dds.fact_station_hour_balance (station_sk);

GRANT CONNECT ON DATABASE dw_dds TO analytics_reader_user;
GRANT USAGE ON SCHEMA dds TO analytics_reader_user;
ALTER DEFAULT PRIVILEGES FOR ROLE hop_dds_user IN SCHEMA dds
    GRANT SELECT ON TABLES TO analytics_reader_user;

ALTER TABLE dds.dim_city OWNER TO hop_dds_user;
ALTER TABLE dds.dim_station OWNER TO hop_dds_user;
ALTER TABLE dds.dim_datetime OWNER TO hop_dds_user;
ALTER TABLE dds.dim_weather_condition OWNER TO hop_dds_user;
ALTER TABLE dds.fact_station_hour_balance OWNER TO hop_dds_user;
