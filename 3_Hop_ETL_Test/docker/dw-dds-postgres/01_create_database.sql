-- DDS layer: Galaxy Schema (Power BI reads directly from dw_dds)

CREATE USER hop_dds WITH PASSWORD 'hop_dds';
CREATE USER analytics_reader WITH PASSWORD 'analytics_reader';

CREATE DATABASE dw_dds OWNER hop_dds;
