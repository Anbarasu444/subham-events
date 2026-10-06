# ADR-0012 — Environments: staging and prod

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("stg and prod is enough"); Firebase projects are created by the user |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (decided) · Claude (documented) |
| Supersedes | — (replaces the earlier Proposed draft with dev/staging/prod, never accepted) |

## Context
Users, test data, push notifications and payments must not mix between testing and production. Development currently runs on localhost (ADR-0010).

## Decision
- **Two environments: `staging` and `prod`.** There is no separate `dev` environment.
- **Local development uses the staging stack**: staging Firebase project, staging (non-prod) ImageKit account/keys, Razorpay **test** mode — with the backend on localhost and the local PostgreSQL database.
- **Firebase:** two projects, `<app>-staging` and `<app>-prod`, **created by the user**. Each holds Android/iOS app registrations for `user_app` and `vendor_app`. (Admins do not use Firebase — ADR-0008.)
- **Flutter flavors:** `staging` and `prod` only (entry points `main_staging.dart`, `main_prod.dart`; Android `applicationIdSuffix` `.stg` for staging). The staging flavor's API base URL comes from the `--dart-define-from-file` config, pointing to the local backend now and to a hosted staging API later.
- **Razorpay:** test mode in local/staging, live mode only in prod.
- **ImageKit:** non-prod account/keys for local/staging (folders `/local`, `/staging`), separate prod account/keys (`/prod`).
- **Firebase client config files** (`google-services.json`, `GoogleService-Info.plist`, `firebase_options_<flavor>.dart`): they are public identifiers, not secrets. Whether to commit them or keep them git-ignored (current root `.gitignore`) is decided in M3/M5 when the user adds them; until then the existing ignore rule stays.

## Consequences
- Fewer projects to create and maintain.
- Local development shares the staging Firebase users and FCM project with any hosted staging later — test accounts must be clearly named; never use real customer data in staging.

## Review trigger
If parallel developers or automated tests start conflicting in the shared staging project (consider a dev project then).
