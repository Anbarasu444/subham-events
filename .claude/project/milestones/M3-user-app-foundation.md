# M3 — User App Foundation

| Field | Value |
|---|---|
| Spec status | **DRAFT** — becomes CONFIRMED when the user issues `START MILESTONE M3` |
| Phase | User App |
| Depends on | M2 COMPLETED and approved (`APPROVE MILESTONE M2`) |
| Primary owner agent | user-app-manager (backend-manager, database-manager for cross-layer items; code-reviewer, security-manager, performance-manager reviewers) |

## Objective
Turn the stock `user_app` Flutter template into the reference-architecture skeleton (`architecture/flutter.md`) and build the backend/database foundation (ADR-0015) so that the app's networking layer talks to a real local NestJS API backed by the local PostgreSQL. No product features, no Firebase sign-in (M5), no splash/bootstrap polish (M4).

## In scope
**User App (`user_app/`)**
1. Folder structure per `architecture/flutter.md` §1 (`app/`, `core/`, `features/`), keeping the existing template project (no re-create).
2. Dependencies (with user approval of `flutter pub add`): `get`, `dio`, `objectbox` (+ generator), `encrypted_shared_preferences`, `flutter_cache_manager`, `cached_network_image`, `device_info_plus`, test libs (`mocktail`). Firebase, FreeRASP and `flutter_native_splash` are **not** added here (M4/M5).
3. Flavors `staging` and `prod` (ADR-0012): `main_staging.dart`, `main_prod.dart`, Android product flavors (`applicationIdSuffix .stg`), iOS schemes; `--dart-define-from-file` config (`config/staging.json`, `config/prod.json`, git-ignored `config/staging.local.json` pointing at the local backend).
4. Final application IDs / bundle identifiers replace `com.example.user_app` (value supplied by the user — open question 1).
5. `core/network`: `ApiClient` (Dio) with base URL, timeouts, `RequestIdInterceptor`, `RetryInterceptor` (idempotent only), dev-only `LoggingInterceptor` with redaction, `ErrorInterceptor`; `ApiException → Failure` mapper for the M1 error catalogue; envelope parsing; cursor/offset pagination models; decimal-rupee money model + formatter (ADR-0014). `AuthInterceptor` is a no-op stub until M5.
6. `core/error`: `Result<T>`, `Failure` hierarchy; `ViewState<T>`; `AsyncStateView` widget (loading skeleton / empty / error + retry / content).
7. `core/theme`: design tokens (colour light/dark, spacing, radii, typography, motion) and `ThemeData`; `core/widgets` base components (`AppButton`, `AppTextField`, skeleton).
8. `core/storage`: `SecureStore` wrapper and ObjectBox store initialisation (no feature boxes yet); cache-manager configuration.
9. GetX routing skeleton: `AppRoutes`, `AppPages`, `InitialBinding`, `AuthGuardMiddleware` stub (always guest until M5), one temporary **diagnostics screen** (staging only) that calls `/api/v1/health/ready` and shows the result through `AsyncStateView` — proves the end-to-end chain.
10. Tests: unit tests for error mapper, interceptors (retry rules, request id), money parsing/formatting, envelope/pagination parsing; widget tests for `AsyncStateView` states; `flutter analyze` clean; `dart format` clean.

**Backend (`backend/`) — cross-layer, ADR-0015**
11. Upgrade the NestJS scaffold from ^10 to **NestJS 11** (ADR-0003) on **Node 24** (ADR-0011): `.nvmrc`, `engines`, ESLint flat config, Jest kept.
12. Foundation: typed validated config (`@nestjs/config`), `.env.example`, global `ValidationPipe`, response-envelope interceptor, exception filter with the M1 error catalogue, request-id middleware, structured logging (pino) with redaction, `helmet`, CORS disabled, `/api/v1` prefix, graceful shutdown, `worker.ts` entry point (empty job loop placeholder only if needed for structure — no jobs yet).
13. `health` module: `GET /api/v1/health/live`, `GET /api/v1/health/ready` (DB check) — documented in `api-contracts.md` Part B.
14. Exact-decimal money utility + DTO validator/transformer for `{ amount, currency }` (ADR-0014), unit-tested (used from M8 on).
15. Tests: unit (filter, interceptor, config validation, money), e2e (`supertest`) for health endpoints and error envelope (404, 422 shapes).

**Database (`database/`) — cross-layer, ADR-0006/0010/0015**
16. TypeORM `DataSource` shared by app and CLI; npm scripts `migration:generate|create|run|revert|show`; `synchronize: false`.
17. Local setup script/README in `database/` for the Homebrew PostgreSQL 18: create `event_planner_dev` and `event_planner_test`, roles `app_rw` and `migrator`, grants. No passwords committed.
18. A first, empty baseline migration (or none) proving the migration pipeline runs against an empty DB; **no domain tables** (users etc. arrive in M5).

**Documentation**
19. `api-contracts.md` Part B (health), `database-schema.md` Part B (migration baseline), `architecture/flutter.md` adjustments discovered during implementation, `current-milestone.md`, `progress.md`.

## Out of scope
- Splash screen, bootstrap ordering, FreeRASP, native splash (M4)
- Firebase, authentication, users table, notifications (M5, M18)
- Navigation shell / bottom navigation (M6), any product feature screens (M7+)
- CI pipeline setup (planned in `architecture/quality.md`; to be scheduled by the user)
- Hosting, cloud resources (ADR-0010)
- `vendor_app/`, `admin_cms/` (phase-locked)

## Deliverables
Restructured `user_app/` skeleton with flavors and core layers; upgraded NestJS 11 backend foundation with health endpoints; TypeORM migration tooling; local DB setup script; tests; updated docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Skeleton, flavors, core layers, diagnostics screen | 1–10 |
| backend | NestJS 11 upgrade, foundation, health module, money utility | 11–15 (ADR-0015) |
| database | DataSource, migration scripts, local setup script, baseline | 16–18 |
| Firebase | None | — (M5) |
| API contracts | Health endpoints (Part B) | 13, 19 |
| Notifications | None | — |

## Acceptance criteria
- [ ] AC-1 `user_app` builds and runs in the `staging` flavor (Android emulator and iOS simulator) and in `prod` flavor (build only); package IDs updated.
- [ ] AC-2 The staging diagnostics screen shows "ready" from the local backend and a clear error + retry state when the backend is stopped (offline/timeout mapped to `Failure`).
- [ ] AC-3 `flutter analyze` reports no issues; `dart format --set-exit-if-changed` passes; all Flutter tests pass.
- [ ] AC-4 Backend runs on NestJS 11 / Node 24; `npm run lint`, `npm test`, `npm run test:e2e`, `npm run build` pass.
- [ ] AC-5 `GET /api/v1/health/live` → 200 envelope; `/health/ready` → 200 when DB reachable, 503 `SERVICE_UNAVAILABLE` envelope otherwise; unknown route → 404 error envelope with `requestId`.
- [ ] AC-6 `npm run migration:run` succeeds against an empty `event_planner_dev` and `event_planner_test`; `synchronize` is false.
- [ ] AC-7 Money utility/validator accepts `"10.10"`, rejects `10.1` (number), `"10.1"`, `"1e3"`, negative values; arithmetic is exact (unit tests).
- [ ] AC-8 No secrets committed (`.env*` ignored, `.env.example` present); logs redact authorization/cookies.
- [ ] AC-9 Only files under `user_app/`, `backend/`, `database/` and `.claude/project/` changed; `vendor_app/` and `admin_cms/` untouched.
- [ ] AC-10 Docs updated; security, performance (cold start of skeleton measured as baseline), code review done; milestone set to IN_REVIEW.

## Required reviews
- Security: config/secrets handling, logging redaction, error leakage, CORS/helmet.
- Performance: baseline cold-start and APK size of the skeleton recorded.
- Notification: N/A (record "no notification impact").
- Code review: code-reviewer on the full diff.
- Documentation: Part B docs, progress.

## Risks and assumptions
- NestJS 10 → 11 upgrade on an empty scaffold is low risk; ESLint 8 → flat config may need adjustments.
- TypeORM CLI with migrations in `database/` (outside `backend/`) may need path configuration; fallback per ADR-0006 is `backend/src/database/migrations/` (record decision).
- Package installs (`flutter pub add`, `npm install`) require the user's permission per `.claude/settings.json`.

## Open questions (answer before or at START)
1. Final Android application ID / iOS bundle ID for the User App (e.g. `com.<company>.eventplanner.user`) and display name.
2. Is the temporary staging diagnostics screen acceptable (removed or hidden in M4/M6)?
3. Apply the local DB setup script yourself, or may Claude run it (`psql` requires permission)?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-06 | Initial DRAFT created during M2 (spec item 9) | M2 scope |
