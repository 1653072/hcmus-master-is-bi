\connect dw_nds

CREATE SCHEMA IF NOT EXISTS nds AUTHORIZATION hop_nds;
ALTER USER hop_nds SET search_path TO nds, public;

CREATE TABLE nds.users (
    user_sk               BIGSERIAL PRIMARY KEY,
    user_id               INTEGER NOT NULL UNIQUE,
    username              VARCHAR(100),
    email                 VARCHAR(255),
    age                   INTEGER,
    gender                CHAR(1),
    occupation            VARCHAR(100),
    created_at            TIMESTAMP,
    last_update_timestamp TIMESTAMP
);

ALTER TABLE nds.users OWNER TO hop_nds;
