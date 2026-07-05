\connect dw_metadata

CREATE SCHEMA IF NOT EXISTS metadata AUTHORIZATION hop_metadata_user;
ALTER USER hop_metadata_user SET search_path TO metadata, public;

CREATE TABLE metadata.source_registry (
    source_name    VARCHAR(100) PRIMARY KEY,
    source_type    VARCHAR(50) NOT NULL,
    connection_ref VARCHAR(100),
    notes          TEXT
);

INSERT INTO metadata.source_registry (source_name, source_type, connection_ref, notes) VALUES
    ('divvy_trips',    's3_csv',     'DIVVY_TRIPS_DIR',    'Pull monthly ZIP; LSET/CET on started_at'),
    ('citibike_trips', 's3_csv',     'CITIBIKE_TRIPS_DIR', 'Pull monthly ZIP; union multi-part CSV'),
    ('noaa_lcd',       'file_pull',  'NOAA_LCD_DIR',       'LCD v2 filtered *_01-05.csv; FM-15 hourly'),
    ('gbfs_station',   'json_push',  'GBFS_STATION_DIR',   'MDM push station_information.json');

ALTER TABLE metadata.source_registry OWNER TO hop_metadata_user;
