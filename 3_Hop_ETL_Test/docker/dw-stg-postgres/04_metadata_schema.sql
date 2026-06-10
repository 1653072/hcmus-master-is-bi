\connect dw_metadata

CREATE SCHEMA IF NOT EXISTS metadata AUTHORIZATION hop_metadata;
ALTER USER hop_metadata SET search_path TO metadata, public;

CREATE TABLE metadata.source_registry (
    source_name    VARCHAR(100) PRIMARY KEY,
    source_type    VARCHAR(50) NOT NULL,
    connection_ref VARCHAR(100),
    notes          TEXT
);

INSERT INTO metadata.source_registry (source_name, source_type, connection_ref, notes) VALUES
    ('ratings_revenues', 'postgresql', 'RATINGS_REVENUES_DB', 'Daily CSV pull'),
    ('users',            'postgresql', 'USERS_DB',            'MDM push (Backend — later)'),
    ('movielens_mongo',  'mongodb',    'MONGO',               'Daily JSONL pull');
