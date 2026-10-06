-- Local development database setup (M3, ADR-0010).
-- Run by the developer (not by the app or CI) against the local PostgreSQL 18:
--
--   psql -d postgres -f database/scripts/setup-local.sql
--
-- You are prompted for both passwords (hidden, not stored in shell history).
-- Idempotent: safe to run again. Never commit real passwords.

\set ON_ERROR_STOP on

\if :{?migrator_password}
\else
  \prompt -s 'Password for role migrator: ' migrator_password
\endif
\if :{?app_password}
\else
  \prompt -s 'Password for role app_rw: ' app_password
\endif

-- Roles -------------------------------------------------------------------
SELECT format('CREATE ROLE migrator LOGIN PASSWORD %L', :'migrator_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'migrator') \gexec
SELECT format('ALTER ROLE migrator WITH LOGIN PASSWORD %L', :'migrator_password') \gexec

SELECT format('CREATE ROLE app_rw LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') \gexec
SELECT format('ALTER ROLE app_rw WITH LOGIN PASSWORD %L', :'app_password') \gexec

-- Databases (owned by the migrator role, which runs all DDL) ---------------
SELECT 'CREATE DATABASE event_planner_dev OWNER migrator ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'event_planner_dev') \gexec
SELECT 'CREATE DATABASE event_planner_test OWNER migrator ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'event_planner_test') \gexec

-- Per-database grants --------------------------------------------------------
\connect event_planner_dev
\ir grants.sql

\connect event_planner_test
\ir grants.sql
