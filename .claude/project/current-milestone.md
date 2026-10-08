# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M11** |
| Milestone name | Budget Management |
| Phase | User App (M3–M23) |
| Status | **NOT_STARTED** |
| Spec | `.claude/project/milestones/M11-budget-management.md` (status: DRAFT 2026-10-08) |
| Started date | — |
| Completed date | — |
| Approval status | Waiting for `START MILESTONE M11` (open questions 1–5 in the spec should be answered first) |

## Objective
Per-event budget planning in exact rupees: total, planned amount per vendor category, unplanned remainder, over-plan warning; committed/paid columns ready for M15/M16 (Option A, to be confirmed).

## Completed work / In-progress work / Blocked work
- None (not started).

## Tests completed
- N/A (not started).

## Reviews
| Review | Status |
|---|---|
| Security review | NOT_STARTED |
| Performance review | NOT_STARTED |
| Notification review | NOT_STARTED |
| Documentation | NOT_STARTED |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-30.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A1 (no manual expenses) relevant to M11.

## Files changed
- None for M11.

## Files pending approval
- M10 files are uncommitted; the user commits personally.

## Next milestone
- M12 — Vendor Discovery (spec drafted at the M11 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M10 Event Details: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M10` issued by the user |
| Spec | `milestones/M10-event-details.md` (CONFIRMED) |

Evidence at approval: media module with ImageKit upload API v2 (single-use signed settings) and server-side verification; event cover set/remove with signed, resized, metadata-free URLs; tabbed event screen (Overview/Checklist/Budget/Vendors) with cover photo flow, Open in Maps, Share; backend 63 unit + 54 e2e, Flutter 178 tests; ImageKit verified live; security, UI and code reviews PASS WITH FINDINGS (fixed; GI-30 logged). Not verified: real in-app cover upload (simulator signed out).

## Earlier milestone — M9 Checklist: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M9` issued by the user |
| Spec | `milestones/M9-checklist.md` (CONFIRMED) |

Evidence at approval: `checklist_items` migration (applied by the user); backend checklist module + checklist summary on events; User App checklist screen (tick with undo, reorder with accessible alternative, add/edit sheet, read-only for non-planning events), event page/card progress, Home Checklist progress, Menu → Checklist picker; backend 57 unit + 43 e2e, Flutter 167 tests; code, security and UI reviews PASS WITH FINDINGS (fixed; GI-27, GI-29 logged). Not verified: signed-in flows on the simulator (simulator signed out).

## Earlier milestone — M8 Event Management: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M8` issued by the user |
| Spec | `milestones/M8-event-management.md` (CONFIRMED) |

Evidence at approval: `events` + `idempotency_keys` migration (applied by the user); backend events module (create with idempotency, cursor lists, edit with version check, cancel/reopen/complete, soft delete, audit, hourly auto-complete); User App My Events, event form and event page, Home upcoming event; backend 55 unit + 29 e2e, Flutter 145 tests; code, security and UI reviews PASS WITH FINDINGS (fixed; GI-27, GI-28 logged). Not verified: signed-in flows on the simulator (user sign-in needed).

## Earlier milestone — M7 Home Dashboard: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M7` issued by the user |
| Spec | `milestones/M7-home-dashboard.md` (CONFIRMED) |

Evidence at approval: home dashboard framework (greeting, call to action, four independent sections with empty/loading/error-retry, pull-to-refresh, guest vs signed-in); 112 Flutter tests; iOS simulator light/dark checks; code + UI reviews PASS WITH FINDINGS (fixed). Carried to M8: "Create your first event" becomes real and switches to "Create event" once events exist.

## Earlier milestone — M6 Main Navigation: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M6` issued by the user |
| Spec | `milestones/M6-main-navigation.md` (CONFIRMED) |

Evidence at approval: shell with Home, Explore, My Events, Menu; nested per-tab navigation, lazy tabs, guest gating with sign-in return, Menu sections with Coming-soon pages, forced sign-out reason shown, tabs reset on sign-out; 96 Flutter tests; iOS simulator checks; UI + code reviews PASS WITH FINDINGS (fixed). Android back-button device check optional (not run).

## Earlier milestones
- M5 Authentication: COMPLETED 2026-10-07 (committed with M6 `f567e61`).
- M4 Splash & App Bootstrap: COMPLETED 2026-10-06 (committed `d7565c3`).
- M3 User App Foundation: COMPLETED 2026-10-06 (committed `e78060f`).
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
