\connect dw_control

-- Source-change detection: keep the latest order-independent content fingerprint
-- per logical source file and an immutable result per ETL run.
CREATE TABLE IF NOT EXISTS control.etl_source_file_manifest (
    source_name          VARCHAR(100) NOT NULL,
    source_file          TEXT NOT NULL,
    current_fingerprint  VARCHAR(32) NOT NULL,
    row_count            BIGINT NOT NULL DEFAULT 0,
    last_load_run_id     VARCHAR(80) NOT NULL,
    last_change_type     VARCHAR(20) NOT NULL,
    first_seen_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_etl_source_file_manifest PRIMARY KEY (source_name, source_file),
    CONSTRAINT ck_etl_source_file_manifest_change
        CHECK (last_change_type IN ('NEW', 'CHANGED', 'UNCHANGED'))
);

CREATE TABLE IF NOT EXISTS control.etl_source_change_result (
    result_id             BIGSERIAL PRIMARY KEY,
    load_run_id           VARCHAR(80) NOT NULL,
    source_name           VARCHAR(100) NOT NULL,
    source_file           TEXT NOT NULL,
    previous_fingerprint  VARCHAR(32),
    current_fingerprint   VARCHAR(32) NOT NULL,
    row_count             BIGINT NOT NULL DEFAULT 0,
    change_type           VARCHAR(20) NOT NULL,
    detected_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_etl_source_change_run_file
        UNIQUE (load_run_id, source_name, source_file),
    CONSTRAINT ck_etl_source_change_result_type
        CHECK (change_type IN ('NEW', 'CHANGED', 'UNCHANGED'))
);

CREATE INDEX IF NOT EXISTS idx_etl_source_change_result_source
    ON control.etl_source_change_result (source_name, source_file, detected_at DESC);

-- Entity matching: exact station id is safe to reconcile automatically;
-- normalized-name matches are candidates only and must be reviewed.
CREATE TABLE IF NOT EXISTS control.etl_entity_match_result (
    result_id              BIGSERIAL PRIMARY KEY,
    load_run_id            VARCHAR(80) NOT NULL,
    source_name            VARCHAR(100) NOT NULL,
    source_entity_key      TEXT NOT NULL,
    source_entity_name     TEXT,
    candidate_master_key   TEXT,
    candidate_master_name  TEXT,
    match_method           VARCHAR(30) NOT NULL,
    confidence             NUMERIC(5,4) NOT NULL,
    requires_review        BOOLEAN NOT NULL DEFAULT TRUE,
    checked_at             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_etl_entity_match_run_entity
        UNIQUE (load_run_id, source_name, source_entity_key),
    CONSTRAINT ck_etl_entity_match_method
        CHECK (match_method IN ('EXACT_ID', 'NORMALIZED_NAME', 'UNMATCHED')),
    CONSTRAINT ck_etl_entity_match_confidence
        CHECK (confidence BETWEEN 0 AND 1)
);

CREATE INDEX IF NOT EXISTS idx_etl_entity_match_review
    ON control.etl_entity_match_result (requires_review, source_name, checked_at DESC);

-- Leakage audit: records whether rows or derived features cross a declared
-- temporal cutoff. This table is also the evidence gate for later mining runs.
CREATE TABLE IF NOT EXISTS control.etl_data_leak_rule_result (
    result_id         BIGSERIAL PRIMARY KEY,
    load_run_id       VARCHAR(80) NOT NULL,
    source_name       VARCHAR(100) NOT NULL,
    rule_code         VARCHAR(80) NOT NULL,
    severity          VARCHAR(20) NOT NULL,
    checked_count     BIGINT NOT NULL DEFAULT 0,
    leak_count        BIGINT NOT NULL DEFAULT 0,
    status            VARCHAR(20) NOT NULL,
    rule_description  TEXT NOT NULL,
    checked_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_etl_data_leak_rule_run
        UNIQUE (load_run_id, source_name, rule_code),
    CONSTRAINT ck_etl_data_leak_rule_status
        CHECK (status IN ('PASS', 'WARNING', 'FAIL')),
    CONSTRAINT ck_etl_data_leak_rule_counts
        CHECK (checked_count >= 0 AND leak_count >= 0 AND leak_count <= checked_count)
);

CREATE INDEX IF NOT EXISTS idx_etl_data_leak_rule_status
    ON control.etl_data_leak_rule_result (status, checked_at DESC);

ALTER TABLE control.etl_source_file_manifest OWNER TO hop_control_user;
ALTER TABLE control.etl_source_change_result OWNER TO hop_control_user;
ALTER TABLE control.etl_entity_match_result OWNER TO hop_control_user;
ALTER TABLE control.etl_data_leak_rule_result OWNER TO hop_control_user;

ALTER SEQUENCE IF EXISTS control.etl_source_change_result_result_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_entity_match_result_result_id_seq OWNER TO hop_control_user;
ALTER SEQUENCE IF EXISTS control.etl_data_leak_rule_result_result_id_seq OWNER TO hop_control_user;
