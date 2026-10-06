# Quality Architecture

> M1 deliverable for spec item 10 / AC-9.

## 1. Testing strategy per layer

| Layer | Tool | What | Minimum bar |
|---|---|---|---|
| Backend domain | Jest | State machines, money calculations, policies | 100% of transitions incl. forbidden ones |
| Backend services | Jest + fakes | Use cases: success, validation, authZ denial, not-found, conflict, notification/audit emission | Every use case |
| Backend repositories / migrations | Jest + real PostgreSQL (local `event_planner_test` DB; CI service container later) | Queries, constraints, indexes exist, migrations up from empty | Every migration applied in CI |
| Backend API (e2e) | Jest + supertest | Contract shape (envelope, error codes), auth required, role/ownership checks, pagination | Every endpoint: happy path + 401 + 403/404 + 422 |
| Payment | Jest + Razorpay fakes, signature fixtures | Order creation amount from DB, signature valid/invalid, webhook replay idempotency, out-of-order events | Mandatory for any payment change |
| Notifications | Jest | Correct recipients/type/entity/deep link per matrix row; no push on internal events | Every matrix row implemented |
| Flutter unit | `flutter_test` + `mocktail` | Controllers, repositories, error mapper, interceptors | Every controller/repository |
| Flutter widget | `flutter_test` | Each screen's loading/empty/error/retry/content states; accessibility labels | Every screen |
| Flutter integration | `integration_test` | Critical journeys per milestone against a stub API | Per milestone spec |
| Admin CMS | Vitest + Testing Library; Playwright | Components/forms; E2E admin flows | From M40 |
| Cross-client E2E | Playwright (CMS) + `integration_test` (apps) against staging | Booking, platform fee, approval flows | M55–M64 |
| Security | Lint rules, dependency audit, authZ e2e matrix | IDOR checks per resource | Every milestone |
| Performance | See §4 | Budgets | Measured at hardening milestones and when a change risks them |

## 2. CI baseline plan (implemented when each project first gets code)

Path-filtered jobs in one pipeline (GitHub Actions assumed; ADR-0004 monorepo):

| Project | Jobs |
|---|---|
| `backend/` | install (`npm ci`) → lint → typecheck → unit → e2e with PostgreSQL 18 service → TypeORM migration check (apply all from empty) → OpenAPI snapshot diff → `npm audit --omit=dev` (high+) → build |
| `user_app/`, `vendor_app/` | `flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze` → `flutter test` → build staging APK (smoke) |
| `admin_cms/` | `npm ci` → lint → typecheck → test → `next build` |
| Repo | secret scanning (gitleaks), commit-message lint (Conventional Commits) |

`main` is protected: merge only via PR from `milestone/Mxx-*` after the milestone is approved (rule 22).

## 3. Observability

| Signal | Backend | Mobile | Admin CMS |
|---|---|---|---|
| Logs | Structured JSON (pino) to stdout (local console now; log platform chosen with the hosting ADR); fields: `requestId`, `userId` (internal id only), `route`, `status`, `latencyMs`; PII redacted | Debug logs only in dev/staging | Server logs to stdout |
| Errors | Logged errors with stack (error-tracking service chosen with the hosting ADR) | Firebase Crashlytics (non-fatal + fatal), scrubbed of PII | Logged errors (same as backend) |
| Metrics | Request rate/latency/error by route, DB pool usage, job queue depth & age, FCM send failures, payment verification failures | Startup time, slow frames (Firebase Performance optional, decided M22) | Request latency |
| Tracing | `X-Request-Id` end-to-end; OpenTelemetry tracing deferred to M68 | Sends `X-Request-Id` | Forwards `X-Request-Id` |
| Alerts (prod, M72) | 5xx rate > 2% 5 min; p95 > budget 15 min; job age > 5 min; payment webhook signature failures; DB CPU > 80% | Crash-free users < 99.5% | — |

## 4. Initial performance budgets

Reference device: mid-range Android (e.g. 4 GB RAM, 2021–2022 mid-tier SoC), 4G network.

| Area | Budget |
|---|---|
| Mobile cold start → first interactive frame | ≤ 2.5 s (p90) |
| Frame rendering | 60 fps target; ≤ 1% janky frames on list scroll |
| Mobile memory | ≤ 250 MB steady-state RSS on main flows |
| Mobile list pages | 20 items/page, images via `thumb` variant, ≤ 300 KB per list page payload (excluding images) |
| App size | Android release APK per ABI ≤ 40 MB |
| API latency (server-side, excluding network) | p95 ≤ 300 ms reads, ≤ 500 ms writes; p99 ≤ 1 s; payment verification p95 ≤ 800 ms |
| DB queries | No query > 100 ms at expected volume; every list query index-backed; no N+1 (repository tests assert query count where risky) |
| Admin CMS | Server-rendered page TTFB p95 ≤ 800 ms; tables paginated (25/50/100) |
| Push delivery | Notification row → FCM send p95 ≤ 30 s |

Budgets are revisited with real measurements at M22, M38, M53 and M66.
