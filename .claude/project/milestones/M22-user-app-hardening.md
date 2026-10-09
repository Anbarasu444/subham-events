# M22 — User App Hardening + Festive Visual Refresh

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M22` on 2026-10-09 (answers received 2026-10-09) |
| Phase | User App |
| Depends on | M21 COMPLETED and approved (`APPROVE MILESTONE M21`) |
| Primary owner agent | ui-manager + user-app-manager (performance-manager, security-manager, qa-manager, code-reviewer reviewers) |

## Context
- The roadmap's M22 is **User App Hardening**: polish, consistency, performance and robustness before the **M23 USER APP FREEZE**.
- On 2026-10-09 the user asked for a **festive redesign** of the main screens: Home with charts, Checklist, Budget, Budget details and Menu. They shared reference screenshots in `Design/` (another event-planning app, used **for inspiration only**; its brand, illustrations and ads are not copied).
- The user also asked that **fonts, theme colours and similar style details live in one file**, so the whole app can be re-themed by editing that file.
- **Colour (user, 2026-10-09):** a golden-yellow → orange → deep burnt-orange gradient (≈ `#F5C842` → `#E8873A` → `#C0461E`), "for now".
- **Font:** the user's choice, Cattalague, is licensed for personal use only (1001fonts FFP: no commercial apps), so a free SIL-OFL alternative is needed (question 1).
- Proposed placement: the redesign is the main scope of M22, together with the hardening items. M23 stays the freeze.

## Objective (proposed)
The User App looks festive, consistent and polished. All visual style comes from one theme file. Home gives an at-a-glance picture of the current event with charts. Checklist, Budget, Budget details and Menu follow the new look. The app is hardened for the freeze.

## In scope (proposed)
**A. Design system: one file to change everything**
1. A single `lib/core/theme/app_style.dart` (name to confirm) holding:
   - brand colours and gradients;
   - font families: a festive heading font and a readable body font;
   - text sizes and weights;
   - corner radii, card and shadow styles, spacing;
   - chart colours.

   `app_theme.dart` and all widgets read only from it. No hard-coded colours or fonts elsewhere (checked by a test and a grep in review).
2. Bundled OFL fonts (assets; licence files included) — needs the user's approval to download the two font files from Google Fonts.
3. Shared festive components:
   - gradient header/app bar;
   - gradient buttons and floating "+" button;
   - section card with an icon title and a "More ›" link;
   - gradient pill tabs;
   - progress bar;
   - donut chart with a legend;
   - coloured-circle icons in place of illustrations.

**B. Screens** (inspired by the references, adapted to our features)

4. **Home**:
   - countdown to the current event (days, hours, minutes, seconds);
   - event switcher;
   - quick-action grid: Checklist, Budget, Vendors, Schedule, Invitation, Explore, …;
   - checklist summary with progress;
   - charts: budget donut (paid / committed / remaining), vendors donut (booked / quoted / enquired), RSVP donut (coming / maybe / not coming).
5. **Checklist**:
   - month pill tabs;
   - task cards with a checkbox, category icon and date;
   - search;
   - gradient "+" button.
6. **Budget**:
   - category pill tabs;
   - item cards with a paid / amount progress bar;
   - "+".
7. **Budget details** (tap an item):
   - Details card;
   - Balance card (amount / paid / pending with a bar);
   - Payments card, list and "+".
8. **Menu**:
   - profile card (photo, name, email, current event);
   - grouped navigation list;
   - about card (app name, version, Help / Rate / Share).
9. The other screens (Events, Explore, vendor details, invitations, notifications, settings) adopt the new theme through the shared components, with no layout redesign.

**C. Hardening**

10. Consistency pass: empty, loading and error states; snackbars; confirmation dialogs.
11. Accessibility: contrast of text on the gradient colours (WCAG AA), 200 % text, screen-reader labels on charts.
12. Performance: chart drawing on low-end devices; image caching; unnecessary rebuilds; a profile pass on a real or low-end emulator.
13. Robustness: offline handling on every screen; and crash-reporter and FreeRASP checks.
14. Golden or screenshot tests for the redesigned screens.

## Out of scope
- **Guests / seating / tables / menus**: no guest-list feature exists. RSVPs come from invitations (M19). A full guest list would need its own milestone.
- Premium / paid plans, ads, "Helpers", data export.
- Messages (hidden until a chat milestone).
- Backend changes, except read-only summary data the Home charts need, if any (Rule 7).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Theme file, fonts, shared components, 5 redesigned screens, hardening | 1–14 |
| backend | Possibly a small Home summary endpoint (vendor status counts, RSVP totals) if existing endpoints are too chatty; evaluated during the milestone | 4 |
| database | None expected | — |
| Notifications | None | — |

## Acceptance criteria
- [x] AC-1 Changing the colours or fonts in the single style file re-themes the whole app. No screen hard-codes colours or font families (test + review). — Evidence: `app_style.dart`; test "the theme takes its font and colours from app_style.dart" and "no screen hard-codes colours or font families".
- [x] AC-2 Home, Checklist, Budget, Budget details and Menu match the agreed festive look. Charts show correct numbers from server data, with all states handled. — Evidence: golden screenshots in `user_app/test/goldens/goldens/`; Home charts source test; checklist month filter and budget details tests; updated Home/Budget/Checklist/Menu tests.
- [x] AC-3 Text contrast meets WCAG AA. All screens work at 200 % text and with a screen reader (charts have text equivalents). — Evidence: `primary` #B0441C for text, white text on gradients with shadow; 200 % tests (Home, Budget, Menu, Checklist); donut charts expose spoken summaries.
- [x] AC-4 Hardening items done, with evidence: performance profile, offline and error states, and screenshot/golden tests. — Partial by decision (answer 6): redesigned screens hardened (states, 200 %, chart semantics, deterministic screenshot tests); wider hardening moves to the M23 freeze.
- [~] AC-5 Checks and tests pass, the Android build works, reviews are done, the docs are updated, and the status is IN_REVIEW. — Evidence: analyze clean, 326 Flutter tests (+13 new, incl. 4 screenshot tests). **Android build not verified: disk full (GI-40).**

## Risks
- Gradient colours with white text can fail contrast. The style file will hold darker text variants.
- Script/decorative fonts reduce readability, so they are used for headings only (question 1).
- The bottom navigation and "current event" concept change how users move around (question 3).
- **Disk space on the Mac is low.** Builds need ~2 GB free (see the M21 report).

## Open questions (please answer before `START MILESTONE M22`)
1. **Fonts.** Which free (OFL) pair? Recommended: **Rozha One** (festive headings) + **Poppins** (everything else). Alternatives: Yatra One + Poppins, Cinzel + Lato, Playfair Display + Nunito. And may I download the two font files from Google Fonts into the app (about 0.5 MB)?
2. **Colours.** Use the gradient from your screenshot (≈ `#F5C842` → `#E8873A` → `#C0461E`) as the brand gradient, with a light warm background. OK?
3. **Bottom navigation.** Today: Home / Explore / My Events / Menu. The references use Home / Checklist / Guests / Budget / Menu, which needs a "current event" that Checklist and Budget show. Pick one:
   - A: keep today's tabs; Checklist and Budget open from Home's quick-action grid. *(recommended: no guest list exists, and Explore stays one tap away)*
   - B: Home / Checklist / Budget / Explore / Menu, with a current-event switcher.
4. **Charts on Home.** Budget, vendors and RSVP donuts plus checklist progress, drawn by our own code with no new package. Or do you prefer the `fl_chart` package (needs your approval)? *(recommended: own code)*
5. **Pictures.** The references use colourful illustrations. Should we use coloured-circle icons for now (no licensing issues), or will you provide illustrations?
6. **Scope.** Do the redesign and the hardening together in M22 (as drafted), or split the redesign into its own milestone before the freeze?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-09 | Initial DRAFT created at the M21 approval gate, including the user's redesign request (Design/ references, single style file, festive colours and font) | User / CLAUDE.md Rule 4 |
| 2026-10-09 | User answer 1 (for now): **Kalam** (Google Fonts, SIL OFL — free for commercial apps) for all text; may change later via the style file. Download approval for the font files still to confirm | User |
| 2026-10-09 | User answers: 1 **download Kalam** approved; 2 colours **OK** (gradient #F5C842 → #E8873A → #C0461E, light warm background); 3 **A** — keep Home / Explore / My Events / Menu, Checklist and Budget from Home's grid; 4 **use `fl_chart`** (package approved); 5 **the user will provide the illustrations** — Claude to send the list; 6 **redesign now**: M22 focuses on the redesign (look close to the references, colourful, festive); hardening limited to the redesigned screens' checks (contrast, 200 %, states, performance of charts), the broader hardening items are verified at the M23 freeze | User |
| 2026-10-09 | CONFIRMED by `START MILESTONE M22` | User |
| 2026-10-09 | Implemented; AC-4 narrowed per answer 6; AC-5 build check blocked by disk (GI-40). Set IN_REVIEW | Claude |
| 2026-10-09 | **Scope addition (user, during review):** illustrations supplied; all picture paths kept in one file `lib/core/assets/app_illustrations.dart` (`AppIllustrations`) so any picture is replaced in one place; empty screens, offline/error, invitation banner, avatar, logo and event pictures wired; guard test against raw asset paths and missing files | User |
