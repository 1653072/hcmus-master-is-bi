-- Staging layer: Staging + Control + Metadata

CREATE USER hop_staging WITH PASSWORD 'hop_staging';
CREATE USER hop_control WITH PASSWORD 'hop_control';
CREATE USER hop_metadata WITH PASSWORD 'hop_metadata';

CREATE DATABASE dw_staging OWNER hop_staging;
CREATE DATABASE dw_control OWNER hop_control;
CREATE DATABASE dw_metadata OWNER hop_metadata;
