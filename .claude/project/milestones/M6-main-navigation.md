# M6 — Main Navigation

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M6` on 2026-10-07 |
| Phase | User App |
| Depends on | M5 COMPLETED and approved (`APPROVE MILESTONE M5`) |
| Primary owner agent | user-app-manager (ui-manager, performance-manager, code-reviewer reviewers) |

## Objective
The User App gets its permanent navigation shell: a bottom navigation bar with the main sections, each keeping its own navigation stack and scroll position, working for guests and signed-in users, replacing the temporary home placeholder. Section contents are empty-state placeholders; real content arrives in M7 (Home), M8+ (Events), M12 (Vendors) and M21 (Profile).

## In scope
1. **Shell screen** with a Material 3 `NavigationBar` and four tabs in this order (user decision 2026-10-07): **Home**, **Explore**, **My Events**, **Menu**.
2. **Per-tab navigation**: each tab has its own nested navigator (GetX nested navigation ids) so pushing screens inside a tab keeps the bottom bar; re-selecting the active tab pops to its root; Android back closes nested pages first, then returns to the Home tab, then exits.
3. **State preservation**: tabs keep their state and scroll position when switching (`IndexedStack` or keep-alive); tabs are built lazily on first visit (performance).
4. **Guest vs signed-in**: guests can open Home and Explore; **My Events** is shown to guests with a sign-in prompt (user decision) that opens the existing sign-in flow and returns to the same tab afterwards; the **Menu** tab is visible to guests with a "Sign in" header and only guest-safe entries (Settings, Help).
5. **Menu tab** (user decision 2026-10-07): a header with the signed-in identity (or "Sign in" for guests) and a list of entries — **My profile**, **Settings**, **Help**, **Schedule**, **Budget**, **Checklist**, **Messages**, plus **Sign out** (signed-in only) and, in staging builds only, **Diagnostics**. M6 builds the menu and its navigation; each entry whose feature belongs to a later milestone opens a clear "Coming soon" placeholder inside the Menu tab: My profile → M21, Budget → M11, Checklist → M9, Schedule (reminders) → M17, Messages → see open question 3, Settings/Help → content defined in M21/M51. The M5 account screen content (signed in as, sign-out) moves into the Menu tab.
6. **Startup routing**: `StartupRouter` opens the shell (Home tab); the M3/M4 home placeholder screen is removed.
7. **Placeholders**: each section shows a purposeful empty state (icon, title, one line of text) — no fake data.
8. **Accessibility & UX**: labelled destinations, selected-state semantics, 48 dp targets, text scaling to 200 %, light/dark themes, brand colour from tokens.
9. **Tests**: widget tests for tab switching, state preservation, re-select-to-root, guest gating and sign-in return, back-button behaviour; controller unit tests.
10. **Docs**: flutter.md routing section updated (shell + nested navigators), current-milestone, progress.

## Out of scope
- Real Home dashboard content (M7), events (M8–M11), vendor discovery (M12–M13), notification centre/badges (M18), profile editing (M21)
- Deep-link routing into tabs (M18)
- Backend or database changes (none expected)
- Vendor App / Admin CMS (phase-locked)

## Deliverables
Navigation shell with four tabs, nested per-tab navigation, guest gating, moved account/diagnostics entry, tests, updated docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Shell, tabs, routing, placeholders | 1–9 |
| backend | None | — |
| database | None | — |
| Firebase | None | — |
| API contracts | None | — |
| Notifications | None (badges in M18) | — |

## Acceptance criteria
- [ ] AC-1 After start-up the app opens the shell on the Home tab (guest or signed in); the old home placeholder no longer exists.
- [ ] AC-2 Switching tabs keeps each tab's state and scroll position; re-selecting the active tab returns to its root (widget tests).
- [ ] AC-3 Pages pushed inside a tab keep the bottom bar visible; Android back pops inside the tab first, then goes to Home, then exits (tests + manual check on Android).
- [ ] AC-4 Guests opening My Events see a sign-in prompt; after signing in they land on My Events (tests + manual check). Guests see a Sign in header in Menu.
- [ ] AC-5 Menu tab shows the signed-in identity (or a Sign in header for guests), the agreed entries in order, sign-out for signed-in users, and Diagnostics only in staging builds; not-yet-built entries open a "Coming soon" placeholder.
- [ ] AC-6 Accessibility: labelled destinations, 200 % text without overflow, light/dark correct (tests + screenshots).
- [ ] AC-7 `flutter analyze` clean, all tests pass; only `user_app/` and `.claude/project/` changed.
- [ ] AC-8 UI/UX, performance (lazy tab build, no jank on switching) and code reviews done; docs updated; IN_REVIEW.

## Required reviews
- UI/UX: section names/icons, empty states, guest prompt copy, accessibility.
- Performance: lazy tab construction, rebuild scope on tab switch.
- Security: guest gating is UX only (backend authorizes) — confirm no protected data is fetched for guests.
- Notification: N/A.

## Risks and assumptions
- GetX nested navigation with `Get.nestedKey` has edge cases with back handling; covered by tests and a manual Android check.
- Section list affects later milestones' entry points — confirm before START (open question 1).

## Open questions
1. ~~Tabs~~ — answered: **Home, Explore, My Events, Menu**.
2. ~~Guests and My Events~~ — answered: **show the tab with a sign-in prompt**.
3. **Messages** in the Menu: the roadmap has enquiries/quotations (M14–M15) but no user↔vendor chat milestone. Should "Messages" mean the enquiry/quotation conversations (M14–M15), or a real-time chat feature (needs a new milestone — not assumed)? M6 only adds the menu entry with a "Coming soon" page either way.
4. **"Home" in the Menu**: the Home tab already exists. Did you mean the Home tab itself (no extra menu entry), or something else (e.g. the event's home/overview page)? Proposed: no separate Home menu entry.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-07 | Initial DRAFT created at the M5 approval gate | CLAUDE.md Rule 4 |
| 2026-10-07 | Answers before START: tabs Home, Explore, My Events, Menu; My Events shown to guests with sign-in prompt; Menu entries My profile, Settings, Help, Schedule, Budget, Checklist, Messages (scope items 1, 4, 5 and AC-4/AC-5 updated). Open: Messages meaning, "Home" menu entry | User |
| 2026-10-07 | CONFIRMED by `START MILESTONE M6` (open questions 3–4 still open; proceeding with: Messages = "Coming soon" entry, no separate Home menu entry) | User |
| 2026-10-07 | Open question 3 answered: users and vendors may talk outside the app **or** inside an in-app Messages feature (user↔vendor messaging). M6 keeps the Messages menu entry as "Coming soon"; where the messaging feature is built is a roadmap decision (see known issue GI-26) | User |
| 2026-10-07 | User: keep Messages as "Coming soon" for now; messaging decided later (GI-26) | User |
