-- Staging layer: dw_staging + dw_control + dw_metadata

CREATE USER hop_staging_user WITH PASSWORD 'hop_staging@123';
CREATE USER hop_control_user WITH PASSWORD 'hop_control@123';
CREATE USER hop_metadata_user WITH PASSWORD 'hop_metadata@123';

CREATE DATABASE dw_staging OWNER hop_staging_user;
CREATE DATABASE dw_control OWNER hop_control_user;
CREATE DATABASE dw_metadata OWNER hop_metadata_user;
