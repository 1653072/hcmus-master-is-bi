\connect dw_staging

CREATE TABLE staging.dq_reject_row (
    reject_id        BIGSERIAL PRIMARY KEY,
    load_run_id      VARCHAR(80) NOT NULL,
    source_name      VARCHAR(100) NOT NULL,
    source_table     VARCHAR(100) NOT NULL,
    source_file      TEXT,
    source_row_number BIGINT,
    business_key     TEXT,
    rule_code        VARCHAR(80) NOT NULL,
    rule_type        VARCHAR(30) NOT NULL,
    reject_reason    TEXT NOT NULL,
    raw_payload      JSONB,
    rejected_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.dq_warning_row (
    warning_id       BIGSERIAL PRIMARY KEY,
    load_run_id      VARCHAR(80) NOT NULL,
    source_name      VARCHAR(100) NOT NULL,
    source_table     VARCHAR(100) NOT NULL,
    source_file      TEXT,
    source_row_number BIGINT,
    business_key     TEXT,
    rule_code        VARCHAR(80) NOT NULL,
    rule_type        VARCHAR(30) NOT NULL,
    warning_reason   TEXT NOT NULL,
    raw_payload      JSONB,
    warned_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dq_reject_run_source ON staging.dq_reject_row (load_run_id, source_name);
CREATE INDEX idx_dq_warning_run_source ON staging.dq_warning_row (load_run_id, source_name);

ALTER TABLE staging.dq_reject_row OWNER TO hop_staging_user;
ALTER TABLE staging.dq_warning_row OWNER TO hop_staging_user;
