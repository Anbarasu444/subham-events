# Flutter Reference Architecture (user_app, vendor_app)

> M1 deliverable for spec item 6 / AC-5. Applies to `user_app` from M3 and to `vendor_app` from M24 (phase lock). Code sharing: ADR-0009 (Accepted) — two separate codebases, no shared package; each app implements this reference independently.
> Toolchain observed on the dev machine: Flutter 3.44.9 stable (Dart SDK constraint `^3.13.5` in `user_app/pubspec.yaml`). Package identifiers are still `com.example.*`; the final application IDs are a user decision recorded in M3.

## 1. Folder structure (feature-first)

```text
lib/
  main_staging.dart | main_prod.dart   # flavor entry points → bootstrap(AppConfig)
  app/
    bootstrap.dart        # ordered init: bindings, Firebase, ObjectBox, FreeRASP, error handlers
    app.dart              # GetMaterialApp, theme, initial route
    config/app_config.dart  # flavor, apiBaseUrl, feature flags (no secrets)
    routes/app_routes.dart  # route name constants
    routes/app_pages.dart   # GetPage list with bindings + middlewares
    bindings/initial_binding.dart  # app-wide singletons
  core/                    # feature-agnostic app infrastructure (owned by this app only — ADR-0009)
    network/              # ApiClient (Dio), interceptors, ApiException mapping, pagination models
    auth/                 # AuthService (Firebase), token provider, session state
    storage/              # SecureStore (encrypted prefs), ObjectBox store, cache manager config
    error/                # Failure types, Result<T>
    state/                # ViewState<T>
    money/                # decimal-rupee Money (ADR-0014)
    security/             # FreeRASP setup + threat handlers
    notifications/        # FCM service, deep-link router (M18)
    theme/                # design tokens, ThemeData, text styles
    widgets/              # shared UI: AppButton, AsyncStateView (loading/empty/error/retry), skeletons
    utils/                # formatters (decimal-rupee strings → display, ADR-0014), date/time (UTC → local)
  features/
    <feature>/
      data/
        models/           # DTOs (fromJson/toJson) matching api-contracts.md
        datasources/      # <feature>_remote_data_source.dart (ApiClient), <feature>_local_data_source.dart (ObjectBox)
        repositories/     # <feature>_repository_impl.dart
      domain/
        entities/         # immutable app models (independent of JSON)
        repositories/     # abstract <feature>_repository.dart
      presentation/
        bindings/         # <feature>_binding.dart (Get.lazyPut)
        controllers/      # <feature>_controller.dart (GetxController)
        views/            # screens
        widgets/          # feature-only widgets
test/                     # mirrors lib/
integration_test/
```

A use-case layer is **not** mandatory; add `domain/usecases/` only when logic spans several repositories (keeps controllers small without ceremony).

## 2. Layer responsibilities

| Layer | Does | Must not |
|---|---|---|
| View (widget) | Render state, forward user intents to controller, `Obx` only around reactive parts | Call Dio/Firebase/ObjectBox, hold business rules |
| Controller (GetX) | Hold screen state (`Rx`), call repositories, map `Result` to UI state, navigation | Parse JSON, build HTTP requests, compute money/permissions |
| Repository | Combine remote + local sources, caching policy, map DTO → entity, return `Result<T>` | Know about widgets or GetX |
| Data source | One technology each: ApiClient, ObjectBox, secure store | Contain business decisions |
| Core services | App-wide singletons (`ApiClient`, `AuthService`, `SecureStore`, `ConnectivityService`) registered in `InitialBinding` with `permanent: true` | Hold feature state |

## 3. State model

Each screen exposes one `Rx<ViewState<T>>`:

```dart
sealed class ViewState<T> { }
class Loading<T> extends ViewState<T> {}
class Content<T> extends ViewState<T> { final T data; final bool isStale; }
class Empty<T>   extends ViewState<T> {}
class Failed<T>  extends ViewState<T> { final Failure failure; }   // carries retry ability (not "Error": avoids shadowing dart:core Error)
```

`AsyncStateView` (core widget) renders loading skeleton / empty / error-with-retry / content consistently (CLAUDE.md §19).

## 4. Result and error model

```dart
sealed class Result<T> { }   // Ok<T>(value) | Err<T>(Failure)

sealed class Failure {        // user-safe message key + optional code from API
  NetworkFailure      // offline, DNS, connection refused
  TimeoutFailure
  UnauthorizedFailure // 401 after refresh attempt → triggers sign-out flow
  ForbiddenFailure    // 403
  NotFoundFailure     // 404
  ValidationFailure   // 422, carries field errors from API envelope
  ConflictFailure     // 409 (e.g. state changed concurrently)
  RateLimitedFailure  // 429, carries retryAfter
  ServerFailure       // 5xx
  UnknownFailure
}
```

`ApiException → Failure` mapping lives only in `core/network/error_mapper.dart`, keyed on HTTP status + API `error.code` (`api-contracts.md` §4).

## 5. Networking (Dio)

`ApiClient` (single Dio instance per app):

| Setting | Value |
|---|---|
| Base URL | `AppConfig.apiBaseUrl` + `/api/v1` (per flavor) |
| Timeouts | connect 10 s, send 20 s (media uploads go directly to ImageKit with their own longer timeout, not through the API), receive 20 s |
| Headers | `Accept: application/json`, `X-Request-Id` (UUID per request), `X-Client: user_app/<version>+<build>`, `Accept-Language` |

Interceptor order:
1. `RequestIdInterceptor`
2. `AuthInterceptor` — attaches Firebase ID token when signed in; single-flight forced refresh + one replay on `401 AUTH_TOKEN_EXPIRED` (see `identity-access.md` §5)
3. `RetryInterceptor` — retries **only idempotent** requests (GET, PUT/DELETE, or requests carrying an `Idempotency-Key`) on network errors, 502/503/504, max 2 retries, exponential backoff with jitter (0.5 s, 1.5 s); honours `Retry-After` on 429
4. `LoggingInterceptor` — dev/staging only; redacts `Authorization`, phone numbers, tokens
5. Error mapping — `ApiClient` catches `DioException` and maps it once via `core/network/error_mapper.dart` (no separate interceptor)

Pagination helper understands both cursor (`meta.page.nextCursor`) and offset meta (ADR-0013).

## 6. Routing and guards (shell since M6)

- `GetMaterialApp` with `getPages` from `AppPages`; named routes in `AppRoutes`.
- **Shell** (`/`, `features/shell`): bottom `NavigationBar` with **Home, Explore, My Events, Menu** (`ShellTab`). `/?tab=<name>` opens a given tab. Each tab has its own nested `Navigator` (key per tab in `ShellController`); tabs are built lazily on first visit, kept alive in an `IndexedStack`, and hidden tabs have tickers disabled.
- Pages that belong to a tab are pushed on that tab's navigator (bottom bar stays). Full-screen flows (sign-in, OTP, diagnostics) use the root GetX navigator.
- Re-selecting the active tab pops it to its first page. System back: pop inside the tab → go to Home → exit.
- Guests: Home, Explore, Menu (Settings, Help) are open; My Events shows a sign-in prompt. Sign-in returns to the originating tab via `returnTo` (allow-list `AppRoutes.returnRoutes`). On sign-out every tab returns to its first page.
- `AuthGuardMiddleware` remains for future full-screen protected routes. Deep links and notification taps (M18) will resolve to `/?tab=…` plus a page inside the tab.

## 6a. Home dashboard sections (M7)

- `features/home`: `HomeController` loads a list of `DashboardSectionSource`s (`domain/dashboard_section.dart`), one `Rx<ViewState<SectionData>>` per `DashboardSectionId`; `DashboardSectionCard` renders title (heading), skeleton / empty (+ optional action) / error with "Try again" / content.
- Sections load **independently** (`Future.wait` of per-section loads; a throwing source is reported to `CrashReporter` and shown as `Failed`). A per-section generation counter drops results of older loads; nothing is written after the controller is closed.
- `requiresSignIn` sources are not called for guests (empty state, no protected API call). Sections reload only when the signed-in/guest status changes, on pull-to-refresh and on retry. A refresh keeps the shown state (`Content` becomes `isStale`, `Empty` stays) instead of flashing skeletons.
- Greeting uses the time of day, refreshed on reload and app resume; first name when signed in.
- M7 registers `EmptySectionSource` placeholders (`defaultDashboardSources` in `ShellBinding`). Owners: Upcoming event → M8, Checklist → M9, Budget → M11, Explore vendors → M12. A milestone filling a section supplies a real source (repository-backed) **and** a `contentBuilder` for its card (a `Content` state without a builder asserts in debug). Each card rebuilds in its own `Obx`.

## 6b. Events feature (M8)

- `features/events`: `EventsRepository` (network-only; events are server-owned, no offline cache yet) exposes a broadcast `changes` stream after every successful write. `MyEventsController` (Upcoming/Past lists, cursor pagination, inline load-more retry) and the Home `UpcomingEventSource` listen to it and reload.
- Event pages (form, detail) live in the My Events tab navigator (`EventsNavigation`, `ShellController.pushInTab`), so the bottom bar stays. Page controllers use `GetBuilder(init:…, global: false)` and are disposed with the page.
- Create requests carry one `Idempotency-Key` per form (reused on retries). Edits send only changed fields plus `version`; a 412/409 shows "changed on another device". The form mirrors the server's validation, maps server field errors to fields, scrolls to errors and asks before discarding changes.
- Dates are calendar dates (`core/utils/date_format.dart`, no `intl` dependency); money input uses `Money.tryParseInput` (exact paise, no doubles).

## 7. Local storage responsibilities

| Store | Use for | Never for |
|---|---|---|
| `encrypted_shared_preferences` (`SecureStore`) | Small sensitive values: cached minimal profile, onboarding flags, last FCM token, locale | Large data, lists |
| ObjectBox (added by the first milestone that caches structured data — not in M3) | Structured read caches (e.g. categories, my events list, checklist snapshot) with `cachedAt` for TTL; offline read of recently viewed data | Authoritative payment/booking/permission state; queued writes (no offline writes until a milestone specifies them) |
| `flutter_cache_manager` / `cached_network_image` | Remote images/media with size-appropriate variants (`media-and-deep-links.md`) | Private media URLs beyond their signed-URL TTL |

Firebase Auth persists its own session (platform keychain/keystore). Sign-out clears SecureStore user keys, ObjectBox user boxes and image cache entries for private media.

Stale-data policy: repositories return cached data as `Content(isStale: true)` immediately, refresh in background, and show a subtle "offline / last updated" indicator. Payment, booking and permission screens always fetch fresh and show an error if offline.

## 8. Environment flavors (ADR-0012)

| Flavor | Entry | Firebase project | API base URL | Razorpay (vendor) |
|---|---|---|---|---|
| staging | `main_staging.dart` | `<app>-staging` | from define file: local backend now (`config/staging.local.json`, git-ignored) / hosted staging later (`config/staging.json`) | test key id |
| prod | `main_prod.dart` | `<app>-prod` | prod API (`config/prod.json`) | live key id |

Android product flavors (`staging`, `prod`; `applicationIdSuffix` `.stg`); **iOS native schemes/configurations are added in M5** together with the per-flavor Firebase plist — until then iOS runs with `-t lib/main_staging.dart --dart-define-from-file=…`. Values come from `--dart-define-from-file` (non-secret only). See `environments.md`.

## 9. Bootstrap order (implemented in M4)

`bootstrap(flavor)` → keep native splash (`FlutterNativeSplash.preserve`) → install error handlers (`FlutterError.onError`, `PlatformDispatcher.onError` → `CrashReporter`) → `Bootstrapper` runs ordered, timed steps:

| Step | Critical | Failure behaviour |
|---|---|---|
| `config` (`AppConfig.fromEnvironment`) | Yes | Start-failure screen with retry |
| `app-version` (`package_info_plus` → `X-Client`) | No | Reported; app starts with placeholder version |
| `runtime-protection` (FreeRASP, observe mode) | No | Reported; app starts unprotected |

Then `runApp(App(initialRoute: StartupRouter().initialRoute()))`, native splash removed after the first frame, first screen fades in (250 ms). M5 adds Firebase/Crashlytics/auth steps; M6 extends `StartupRouter`. Step timings are logged on every start.
Budget: cold start to first frame ≤ 2.5 s on a mid-range device (`quality.md`).

## 10. FreeRASP placement (implemented in M4)

- `core/security/runtime_protection.dart`, started once per process from bootstrap; callbacks only **log** (observe mode) — reactions decided in M22.
- Configuration via `--dart-define`: `TALSEC_WATCHER_MAIL`, `TALSEC_SIGNING_CERT_HASHES` (base64 SHA-256, comma-separated), `TALSEC_IOS_TEAM_ID`. Without them FreeRASP stays off (logged; reported as an error in prod builds).
- FreeRASP sends threat reports (threat type, app id, device identifiers/model, OS) to Talsec — a third-party data flow that needs an ADR and privacy-policy / store-label disclosure before any distribution (known issue GI-14).
- Debug/simulator builds trigger `onDebug`/`onSimulator`/`onDevMode`; M22 must gate reactions per flavor.

## 11. Theming / design tokens

- `core/theme/tokens.dart`: brand colour `#FF7E7E` (seed only — fails text contrast on white; use `colorScheme.primary` for text/buttons), spacing scale (4-pt grid), radii, sizes (touch target 48, hero icon 64), motion durations (150/250/350 ms). Elevation/typography tokens are added when the first screens need them.
- Native splash (`flutter_native_splash`, config in `pubspec.yaml`): colour-only `#FF7E7E` (light) / `#3A1F1F` (dark) until a logo exists.
- `ThemeData` built from tokens with Material 3; widgets reference `Theme.of(context)` / token extensions, never hard-coded values.
- Accessibility: minimum touch target 48×48 dp, text scaling up to 200% without clipping, contrast ≥ 4.5:1 for body text.
- Vendor app uses the same token structure with its own brand accent (decided at M24).

## 12. Testing per layer

Controllers and repositories unit-tested with fakes (`mocktail`), widgets with `flutter_test`, critical flows with `integration_test`. See `quality.md`.
