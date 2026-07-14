\connect dw_dds

-- Idempotent hierarchy attributes required by the Mondrian Time dimension.
-- This also upgrades an existing DDS volume created before these columns existed.
ALTER TABLE dds.dim_datetime
    ADD COLUMN IF NOT EXISTS year SMALLINT,
    ADD COLUMN IF NOT EXISTS quarter SMALLINT,
    ADD COLUMN IF NOT EXISTS month_name VARCHAR(20);

UPDATE dds.dim_datetime
SET year = EXTRACT(YEAR FROM date)::SMALLINT,
    quarter = EXTRACT(QUARTER FROM date)::SMALLINT,
    month_name = TRIM(TO_CHAR(date, 'Month'))
WHERE year IS NULL OR quarter IS NULL OR month_name IS NULL;

ALTER TABLE dds.dim_datetime
    ALTER COLUMN year SET NOT NULL,
    ALTER COLUMN quarter SET NOT NULL,
    ALTER COLUMN month_name SET NOT NULL;

ALTER TABLE dds.dim_datetime
    DROP CONSTRAINT IF EXISTS ck_dim_datetime_quarter;

ALTER TABLE dds.dim_datetime
    ADD CONSTRAINT ck_dim_datetime_quarter CHECK (quarter BETWEEN 1 AND 4);

ALTER TABLE dds.dim_datetime OWNER TO hop_dds_user;
