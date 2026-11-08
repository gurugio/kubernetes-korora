\set ON_ERROR_STOP on
SELECT 'CREATE ROLE korora_writer LOGIN NOINHERIT' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'korora_writer') \gexec
SELECT 'CREATE ROLE korora_reader LOGIN NOINHERIT' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'korora_reader') \gexec
ALTER ROLE korora_writer PASSWORD :'writer_password';
ALTER ROLE korora_reader PASSWORD :'reader_password';
CREATE SCHEMA IF NOT EXISTS api;
CREATE TABLE IF NOT EXISTS api.measurements (
 event_id uuid PRIMARY KEY,
 device text NOT NULL CHECK (length(device) BETWEEN 1 AND 128),
 metric text NOT NULL CHECK (length(metric) BETWEEN 1 AND 128),
 observed_at timestamptz NOT NULL,
 value double precision NOT NULL
);
CREATE INDEX IF NOT EXISTS measurements_device_time ON api.measurements (device, observed_at DESC);
REVOKE ALL ON SCHEMA api FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA api FROM PUBLIC;
REVOKE ALL ON api.measurements FROM korora_writer, korora_reader;
GRANT USAGE ON SCHEMA api TO korora_writer, korora_reader;
GRANT INSERT ON api.measurements TO korora_writer;
GRANT SELECT ON api.measurements TO korora_reader;
