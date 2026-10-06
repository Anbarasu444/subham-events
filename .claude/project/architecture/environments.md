# Environments, Configuration and Secrets

> M1 deliverable for spec item 9 / AC-8. Decisions: ADR-0010 (hosting deferred — localhost + local PostgreSQL now, Accepted), ADR-0012 (environments: staging + prod, Accepted).
> "Secret store" below = git-ignored local `.env` now; the hosted secret manager is chosen in the hosting ADR.

## 1. Environment matrix

**Current (ADR-0010):** development runs only on the developer's Mac — **localhost + local PostgreSQL**. Hosted environments are defined later by a hosting ADR (at the latest M72).

| | local (now) — uses the staging stack | staging / prod (hosted later — hosting ADR) |
|---|---|---|
| Purpose | Developer machine; all milestone work until hosting is decided | Shared testing, release candidates, production |
| Backend API | `npm run start:dev` on `http://localhost:3000` | Hosting TBD |
| Worker | `npm run start:worker` (localhost) | Hosting TBD |
| PostgreSQL | Local PostgreSQL 18.x (Homebrew, observed 18.4), database `event_planner_dev` (+ `event_planner_test` for integration tests) | Managed PostgreSQL TBD (backups + point-in-time recovery required for prod) |
| Firebase project | `<app>-staging` (created by the user; Auth emulator optional for tests) | `<app>-staging`, `<app>-prod` (ADR-0012, created by the user) |
| Media (ImageKit.io) | non-prod ImageKit account/keys, folder `/local` | non-prod account (`/staging`), **prod account** (`/prod`) |
| Razorpay | test mode | test mode except **live** in prod |
| Admin CMS | `npm run dev` on `http://localhost:3001` (from M40); admins log in with username + password (no Firebase) | Hosting TBD |
| Mobile apps | staging flavor with local define file → backend at `10.0.2.2:3000` (Android emulator), `localhost:3000` (iOS simulator), Mac LAN IP (physical device) | staging / prod flavors |
| Data | Local seed fixtures | Synthetic test data in non-prod; real data only in prod |

## 2. Configuration catalogue

| Variable | Used by | Secret? | Source |
|---|---|---|---|
| `NODE_ENV`, `APP_ENV` | backend, CMS | No | env |
| `PORT` | backend, CMS | No | platform |
| `DATABASE_URL` (app role) | backend | **Yes** | Secret store |
| `DATABASE_MIGRATION_URL` (migrator role) | CI migrate step | **Yes** | Local `.env` now; CI/hosted secret store later |
| `FIREBASE_PROJECT_ID` | backend | No | env |
| Firebase Admin credentials | backend | **Yes** | Local: service-account JSON file stored **outside the repository**, path in `GOOGLE_APPLICATION_CREDENTIALS`; hosted: keyless workload identity if the hosting provider supports it |
| `RAZORPAY_KEY_ID` | backend, vendor_app | No (public) | env / flavor config |
| `RAZORPAY_KEY_SECRET` | backend | **Yes** | Secret store |
| `RAZORPAY_WEBHOOK_SECRET` | backend | **Yes** | Secret store |
| `IMAGEKIT_PUBLIC_KEY`, `IMAGEKIT_URL_ENDPOINT`, `MEDIA_ROOT_FOLDER` | backend (returned to apps in upload intents) | No (public) | env |
| `IMAGEKIT_PRIVATE_KEY` | backend | **Yes** | Secret store |
| `CORS_ALLOWED_ORIGINS` | backend | No | env |
| `ADMIN_CMS_API_BASE_URL` | CMS server | No | env |
| `apiBaseUrl`, `flavor`, `razorpayKeyId` | Flutter apps | No | `config/<flavor>.json` via `--dart-define-from-file` |
| Firebase client config (`google-services.json`, `GoogleService-Info.plist`, `firebase_options*.dart`) | Flutter apps | No (public, restricted by App Check + API key restrictions) | Per flavor (staging, prod); commit vs git-ignore decided in M3/M5 (ADR-0012) |
| `LOG_LEVEL` | backend, CMS | No | env |

**No client app requires any secret.** Everything shipped to devices or browsers is a public identifier; protection comes from Firebase App Check, API-key restrictions (package name / SHA-1 / bundle ID / HTTP referrer), backend authorization and Razorpay server-side verification.

## 3. Policies

- `.env.example` per runnable project (`backend/`, `admin_cms/`) lists every variable with dummy values and a comment; real `.env*` files are git-ignored (already enforced by root `.gitignore`) and denied to Claude in `.claude/settings.json`.
- Backend config is schema-validated at boot; the process exits on missing/invalid variables.
- Secrets are never logged, never returned by any endpoint, never placed in Flutter `--dart-define` or `NEXT_PUBLIC_*` variables.
- Secret rotation: Razorpay keys, webhook secret and ImageKit private key rotatable without redeploying clients.
- Separate DB roles (created locally too, from M3): `app_rw` (DML, but `UPDATE`/`DELETE` explicitly revoked on append-only tables `audit_logs` and `provider_events`), `migrator` (DDL), `readonly_reports` (reports, M52).
- Backups (hosted, later): encrypted automated backups + point-in-time recovery, restorable only by named operators; restore drills in M71. Local development data is disposable (re-created from migrations + seeds).
- CI (when introduced) uses short-lived/OIDC credentials for any cloud access — no long-lived keys in CI secrets.
- Prod access is limited to named operators; admin data fixes go through audited admin endpoints, not ad-hoc SQL (break-glass procedure documented in M72).
