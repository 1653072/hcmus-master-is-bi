-- Staging layer: dw_staging + dw_control

CREATE USER hop_staging_user WITH PASSWORD 'hop_staging@123';
CREATE USER hop_control_user WITH PASSWORD 'hop_control@123';

CREATE DATABASE dw_staging OWNER hop_staging_user;
CREATE DATABASE dw_control OWNER hop_control_user;
