-- DDS layer: Star schema (Power BI reads dw_dds)

CREATE USER hop_dds_user WITH PASSWORD 'hop_dds@123';
CREATE USER analytics_reader_user WITH PASSWORD 'analytics_reader@123';

CREATE DATABASE dw_dds OWNER hop_dds_user;
