\connect dw_staging

CREATE SCHEMA IF NOT EXISTS staging AUTHORIZATION hop_staging;
ALTER USER hop_staging SET search_path TO staging, public;

CREATE TABLE staging.stg_ratings (
    rating_id             INTEGER,
    user_id               INTEGER,
    movie_id              VARCHAR(50),
    rating                NUMERIC(3, 1),
    rated_at              TIMESTAMP,
    last_update_timestamp TIMESTAMP,
    batch_id              VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.stg_revenues (
    revenue_id            INTEGER,
    movie_id              VARCHAR(50),
    region                VARCHAR(100),
    revenue_amount        NUMERIC(15, 2),
    currency              VARCHAR(10),
    revenue_date          DATE,
    last_update_timestamp TIMESTAMP,
    batch_id              VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.stg_users (
    user_id               INTEGER NOT NULL UNIQUE,
    username              VARCHAR(100),
    email                 VARCHAR(255),
    age                   INTEGER,
    gender                CHAR(1),
    occupation            VARCHAR(100),
    created_at            TIMESTAMP,
    last_update_timestamp TIMESTAMP,
    operation             VARCHAR(10),
    batch_id              VARCHAR(80),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.stg_movies (
    movie_id              VARCHAR(50),
    title                 VARCHAR(500),
    release_year          VARCHAR(10),
    genres                TEXT,
    runtime_minutes       INTEGER,
    batch_id              VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.stg_genres (
    genre_id              VARCHAR(50),
    name                  VARCHAR(200),
    batch_id              VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.stg_persons (
    person_id             VARCHAR(50),
    name                  VARCHAR(200),
    role                  VARCHAR(100),
    birth_year            INTEGER,
    batch_id              VARCHAR(50),
    loaded_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Init scripts run as postgres; transfer ownership so hop_staging can read/write via Hop
ALTER TABLE staging.stg_ratings OWNER TO hop_staging;
ALTER TABLE staging.stg_revenues OWNER TO hop_staging;
ALTER TABLE staging.stg_users OWNER TO hop_staging;
ALTER TABLE staging.stg_movies OWNER TO hop_staging;
ALTER TABLE staging.stg_genres OWNER TO hop_staging;
ALTER TABLE staging.stg_persons OWNER TO hop_staging;
