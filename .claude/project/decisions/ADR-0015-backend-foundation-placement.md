# ADR-0015 — Backend and database foundation is built in M3 under the cross-layer rule

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("backend starts with M3") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (ratifies) · Claude (proposes) |
| Supersedes | — |

## Context
There is no backend milestone (ADR-0002). M3 (User App Foundation) needs a reachable API to validate the Dio client, error mapping and environments end to end; M5 (Authentication) needs auth, users and the first migrations (open question 9).

## Options considered
1. **Foundation in M3** — NestJS 11 upgrade (ADR-0003), config schema, logging, request IDs, error envelope, health endpoints, TypeORM DataSource + migration scripts (ADR-0006), local PostgreSQL setup script (ADR-0010), CI skeleton for backend; traced to M3's in-scope "networking foundation" items.
2. **Foundation in M5** — M3 would build the Dio layer against no server; M5 becomes very large.
3. **Insert a dedicated backend milestone** — changes the roadmap numbering (requires a governance change).

## Decision
Option 1. The M3 spec (drafted at the M2 gate) will list the backend/database foundation as cross-layer in-scope items with acceptance criteria (health endpoint reachable from the staging flavor pointed at the local backend, error envelope contract tests, empty-DB migration run in CI). No domain tables/endpoints beyond what M3 needs.

## Consequences
- M3 is a larger milestone; its spec must be explicit to avoid scope creep.
- Auth, users, roles, audit and jobs tables arrive in M5.

## Review trigger
M3 spec review.
