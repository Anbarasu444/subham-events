# ADR-0003 — NestJS major version: 11.x

| Field | Value |
|---|---|
| Status | **Proposed** — awaiting user ratification (listed for ratification in M1, open question AC-10) |
| Date | 2026-10-06 |
| Milestone | Governance initialization (ratify in M1; execute when backend work first begins) |
| Deciders | User (ratifies) · Claude (proposes) |
| Supersedes | — |

## Context
- `backend/` is the stock NestJS CLI scaffold pinned to `@nestjs/*` **^10.0.0**, with `@nestjs/cli` ^10, ESLint 8, Jest 29. Dependencies are not installed and there is no application code beyond the default `AppModule`, so the cost of changing major version now is close to zero.
- NestJS 11 has been the stable line since early 2025 and still receives patch releases (11.2.x in Aug 2026).
- NestJS **12.0.0** was released around August 2026: full ESM packaging (with CJS compatibility), Vitest instead of Jest for ESM projects, oxlint instead of ESLint, Rspack instead of webpack, Standard Schema support in route decorators, a new `@nestjs/observe` SDK, and a Node.js ≥ 20.19 requirement. At the time of this decision it is weeks old.
- The project relies on ecosystem packages (ORM integration, Firebase Admin, config, throttler, Swagger/OpenAPI, Razorpay SDK) whose v12/ESM readiness is not yet proven.

## Options considered
1. **Stay on 10.x** — out of active development; would force a migration mid-project. Rejected.
2. **Adopt 11.x (latest 11.2.x)** — mature, widely documented, ecosystem fully compatible; upgrade from the empty v10 scaffold is trivial. Later move to 12 needs a planned migration.
3. **Adopt 12.x now** — newest features (ESM, observability SDK) and avoids a future major upgrade; but early-adopter risk on a production payment platform, ecosystem lag, and toolchain changes (Vitest/oxlint/Rspack) the governance rules don't yet assume.

## Decision (proposed)
Adopt **NestJS 11.x (latest 11.2.x patch)** with Node.js active LTS (exact version decided in M1). The upgrade from ^10 is performed as the first backend step of the first milestone that writes backend code (expected M3 under Rule 7), before any feature module exists. Keep CommonJS, Jest and ESLint (flat config) as the backend defaults.

## Consequences
- Stable, well-supported baseline for the whole User App phase.
- A NestJS 12 migration will be needed later; it is cheapest before the Vendor App phase extends the backend.
- Avoid patterns that are known to block ESM migration (e.g. `__dirname` reliance, CJS-only packages where alternatives exist).

## Review trigger
Re-evaluate at M22 (User App Hardening) or earlier if a required library drops NestJS 11 support. Target decision on NestJS 12 before M24.
