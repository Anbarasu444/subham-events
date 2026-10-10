# M24 — Vendor Foundation

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M24` on 2026-10-10 |
| Phase | Vendor App (M24–M39) — first Vendor App milestone |
| Depends on | M23 COMPLETED and approved (`APPROVE MILESTONE M23`, 2026-10-10) |
| Primary owner agent | vendor-app-manager (ui-manager design; code-reviewer, security-manager, performance-manager reviewers) |

## Objective
Turn the stock `vendor_app` Flutter template into the same reference architecture the User App uses (`architecture/flutter.md`), with its own vendor look, splash and start-up, so that later Vendor milestones (sign-in M25, profile M26, listings M27+) only add features. The app starts, shows a branded splash, runs the bootstrap steps, and reaches a placeholder home that proves it can call the local backend.

## In scope
**Vendor App (`vendor_app/`, existing template — not re-created)**
1. Folder structure per `architecture/flutter.md` §1 (`app/`, `core/`, `features/`).
2. Dependencies matching the User App: GetX, Dio, ObjectBox, encrypted_shared_preferences, flutter_cache_manager, cached_network_image, device_info_plus, package_info_plus, flutter_native_splash, Firebase core + Crashlytics, FreeRASP (off until GI-14), test libraries. Firebase Auth/FCM are added in M25/M36.
3. Flavors `staging` / `prod` (`.stg` suffix, `main_staging.dart` / `main_prod.dart`, iOS schemes), config via `--dart-define-from-file` (`config/staging.json`, git-ignored `config/staging.local.json`).
4. Core layer: networking (`ApiClient`, interceptors, error mapping), `Result`/`Failure`, `ViewState` + `AsyncStateView`, storage wrappers, crash reporter, bootstrapper with a start-failure screen.
5. **One style file** `core/theme/app_style.dart` (vendor brand colours, font, gradients) and **one illustrations file** `core/assets/app_illustrations.dart`, like the User App (question 2).
6. Native splash and app name ("… Vendor" / "… Vendor STG").
7. GetX routing skeleton and a placeholder home (staging diagnostics: calls `/api/v1/health/ready`).
8. Tests: unit tests for core (error mapper, interceptors, config), widget tests for the state views and the style-file guard; `flutter analyze` clean.

## Out of scope
- Vendor sign-in (M25), vendor profile (M26), categories/listings (M27+), Razorpay (M29), notifications (M36).
- Any change to the frozen User App, except a shared fix if a backend change requires it.
- Sharing code with `user_app` through a package (question 3).

## Deliverables
Vendor App skeleton, flavors, config, splash, theme files, core layer, placeholder home, tests; docs updated (`architecture/flutter.md` vendor notes, `current-milestone.md`, `progress.md`).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| vendor_app | Foundation (all of the above) | 1–8 |
| backend | None expected (health endpoint exists) | 7 |
| database | None | — |
| Firebase | Use existing vendor configs (GI-20); add `.stg` app if missing | 2–3 |
| API contracts | None | — |
| Notifications | None | — |

## Acceptance criteria
- [x] AC-1 The vendor app builds and runs (staging) on Android and the iOS simulator; splash → placeholder home; health call succeeds against the local backend. — Evidence: staging debug build runs on the iOS simulator (iPhone 16) and on the user's Android phone (Redmi M2101K7AI); splash → home; "Server connection: Connected" (`GET /health/ready` 200).
- [x] AC-2 The structure, core layer and flavors match `architecture/flutter.md`; the start-failure screen appears when config is missing. — Evidence: structure `app/`, `core/`, `features/{home,diagnostics}`; Android flavors `.stg`/prod with "Subam Vendor (STG)"; iOS staging/prod schemes and `config/<flavor>/`; copied bootstrapper/startup-failure tests pass (missing `API_BASE_URL` → start-failure screen).
- [x] AC-3 All colours/fonts come from `app_style.dart`; all pictures from `app_illustrations.dart` (guard tests). — Evidence: `vendor_style_test.dart` (theme from style file, exact gradient #11998E → #38EF7D, AA contrast for white text, no hard-coded colours/fonts/picture paths, illustration fallback).
- [x] AC-4 analyze clean; tests pass; User App tests still pass (no regressions). — Evidence: vendor analyze clean, 55/55 tests; `user_app/` not modified (git status).
- [x] AC-5 Reviews done; docs updated; status IN_REVIEW. — Evidence: reviews in `current-milestone.md`; docs updated.

## Required reviews
Security (no secrets, release cleartext off, backup off), performance (start-up path), notification (none — confirm), documentation.

## Risks and assumptions
- Same package-id placeholder issue as the User App (`com.example.vendor_app`; GI-5-like) — fix in M72 unless the user decides now.
- Duplicating the User App core code in the Vendor App (simple, but two copies to maintain).

## Open questions (please answer before `START MILESTONE M24`)
1. **App name:** what should the vendor app be called on the phone (e.g. "Subham Vendor", "Event Planner Partner")? Keep a placeholder for now?
2. **Look:** reuse the User App's festive style (Kalam font, saffron → rose) with a different accent, or a more business-like style for vendors (cleaner font, calmer colours)? Do you have reference screenshots like you did for the User App?
3. **Code sharing:** copy the User App's core layer into the Vendor App (recommended now — simple, the User App stays frozen), or create a shared Flutter package used by both (cleaner long-term, but changes the frozen User App)?
4. **Illustrations:** will you supply vendor pictures later (I'll send a list with sizes), using icon fallbacks until then?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-10 | Initial DRAFT created at the M23 approval gate | CLAUDE.md Rule 4 |
| 2026-10-10 | User answers: 1 app name **"Subam Vendor"** (staging "Subam Vendor STG"); 2 **same festive style** (Kalam) with a **mint → aqua gradient `#B9FBC0 → #98F5E1`** as the vendor accent; text on it must be dark (white text fails contrast on these light colours) — AA-safe text shades added in `app_style.dart`; 3 **copy** the User App core into `vendor_app` (no shared package; frozen User App untouched; apps stay separate); 4 the user supplies vendor illustrations later (list sent 2026-10-10), icon fallbacks until then | User |
| 2026-10-10 | **Accent changed (user):** vendor gradient is **`#11998E → #38EF7D`** (teal → green), replacing `#B9FBC0 → #98F5E1`. Text on it: white fails contrast on both ends (3.5:1 / 1.5:1), so text-bearing fills use AA-safe deeper shades (white text ≥ 4.5:1) and the exact gradient is kept for decoration — same approach as the User App | User |
| 2026-10-10 | CONFIRMED by `START MILESTONE M24` | User |
| 2026-10-10 | Implemented; set IN_REVIEW | Claude |
