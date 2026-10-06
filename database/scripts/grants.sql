-- Included by setup-local.sql for each database.
-- migrator: owns the schema and runs migrations (DDL).
-- app_rw:   the API's runtime role — data access only, no DDL.
ALTER SCHEMA public OWNER TO migrator;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO migrator;
GRANT USAGE ON SCHEMA public TO app_rw;
SELECT format('REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO app_rw, migrator', current_database()) \gexec

-- Tables and sequences created later by migrator are usable by app_rw.
-- Append-only tables (audit_logs, provider_events) revoke UPDATE/DELETE in
-- their own migrations (architecture/environments.md §3).
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO app_rw;
