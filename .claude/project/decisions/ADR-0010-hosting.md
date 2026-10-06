# ADR-0010 — Hosting: deferred; local development on localhost with a local PostgreSQL

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("I plan hosting later; for now we run in localhost with local postgres db") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (decided) · Claude (documented) |
| Supersedes | — (replaces the earlier Proposed draft recommending Google Cloud, never accepted) |

## Context
Production hosting (servers, managed database, secrets store, logging) is not needed until the platform approaches release. The developer machine has PostgreSQL 18.4 installed via Homebrew (observed 2026-10-06).

## Decision
- **Now:** the backend (API + worker) and the Admin CMS (from M40) run on **localhost**; the database is the **locally installed PostgreSQL** (18.x, Homebrew) on the developer's Mac. Mobile apps (emulator/simulator/device) call the backend on the developer machine (`10.0.2.2` from the Android emulator, `localhost` from the iOS simulator, LAN IP from a physical device — configured per flavor in M3).
- Secrets for local development live in git-ignored `.env` files (`.env.example` committed with dummy values).
- **Later:** the hosting provider, region, managed database, secret store, logging/monitoring and backups are decided in a new ADR before the first non-local deployment — at the latest in M72 (Production Readiness). The architecture keeps hosting-neutral seams: config only via environment variables, stateless API processes, worker as a separate entry point, health endpoints, structured logs to stdout.
- Nothing is created in any cloud account by Claude.

## Consequences
- Zero hosting cost and setup during development.
- Hosting-specific items in the docs (edge rate limiting, managed backups, secret manager, centralized logging, CI cloud credentials) are marked "deferred to the hosting ADR".
- Shared testing by other people (e.g. testers on staging) needs a hosted environment — that triggers the hosting ADR earlier.

## Review trigger
Need for a shared/staging environment, external testers, or M72 at the latest.
