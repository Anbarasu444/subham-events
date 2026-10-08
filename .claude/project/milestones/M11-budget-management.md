# M11 — Budget Management

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M11` on 2026-10-08; open questions answered by the user and scope extended with own expenses (see change log) |
| Phase | User App |
| Depends on | M10 COMPLETED and approved (`APPROVE MILESTONE M10`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (payment-manager for money rules, security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
The budget model (`domain-model.md` §7) compares, per vendor category:
- **Planned** — the user's amounts.
- **Committed** — agreed amounts of confirmed bookings. Bookings come in M15.
- **Paid** — the user's own payment notes. These come in M16.

Vendor categories themselves are created with vendor discovery (M12). So M11 comes before most of the data it summarises, the same situation as M7. Options (open question 1):

- **Option A — plan now, fill later (recommended).**
  - M11 creates the vendor **categories** list: the same `vendor_categories` table M12 uses, seeded with a starter list, read-only for users.
  - Users plan a total budget and an amount per category for each event.
  - "Committed" and "Paid" are shown as ₹0 with an honest "appears after bookings" note. M15/M16 fill them in through the same screen.
- **Option B — move M11 after M16.** The budget is built once bookings and payments exist. This needs a roadmap change.
- **Option C — free-text budget lines.** The user types their own budget lines (e.g. "Photographer"). This is simpler now, but it won't match vendor categories when bookings arrive, and it would conflict with A1 ("budget only tracks platform vendors").

## Objective (Option A)
For each event, the user sees and plans their money in exact rupees:
- the total budget,
- a planned amount per vendor category,
- the remaining unplanned amount,
- a clear warning when the plan exceeds the total.

The event's **Budget tab** (M10 placeholder) and the Home **Budget overview** section show it. Committed and Paid columns are in place for M15/M16.

## In scope (Option A)
**Database (cross-layer, Rule 7)**
1. Migrations:
   - `vendor_categories` (database-schema.md Part C: name, slug, description, status, sort_order; icon later) with a **seed** of the starter list (open question 2), status PUBLISHED.
   - `budget_allocations` (`event_id`, `category_id`, `planned_amount numeric(12,2) ≥ 0`, `currency`; unique per event and category; soft delete).

**Backend (cross-layer, Rule 7)**
2. `GET /api/v1/vendor-categories`: public, PUBLISHED only, in sort order. M12 reuses it.
3. `budget` module, owner-only through the event (another user's event → 404):
   - `GET /api/v1/events/{id}/budget`
     - Totals: total budget, planned sum, unplanned (total − planned), committed (0 until M15), paid (0 until M16), remaining.
     - Per-category rows: planned, committed, paid.
     - All amounts are exact decimal strings (ADR-0014).
   - `PUT /api/v1/events/{id}/budget/allocations/{categoryId}` sets a planned amount; `DELETE` clears it.
   - Editing the total stays in the event edit (M8). Optionally the budget screen can edit it too (open question 4).
   - Writes are allowed only while the event is PLANNING (open question 3). Writes are rate limited and audited.
   - `EventDto` gains a small `budget` summary (planned and total) only if the Home section needs it. Otherwise Home calls the budget endpoint.

**User App**
4. Budget tab on the event screen:
   - Total budget card with "Planned ₹X of ₹Y" and a progress bar.
   - A warning when the planned sum is over the total, and the unplanned remainder.
   - The category list with planned amounts.
   - Add or edit an amount in a sheet with exact rupee input; clear it with confirmation.
   - Committed and Paid shown honestly as "after bookings" (₹0).
   - Loading, empty, error, retry and offline states.
5. Home **Budget overview** section: the next event's total, planned and unplanned figures, with "Open budget" (switches to that event's Budget tab).
6. **Menu → Budget**: picker like Menu → Checklist (one event opens directly).
7. Tests:
   - Backend unit and e2e tests: ownership, exact money (no floating point), sums, over-plan, read-only events, categories seed and public list, migrations.
   - Flutter tests: controller, repository and widgets, including rupee input, warnings, Home section and 200 % text.
8. Docs: api-contracts, database-schema, domain-model (category seed decision), flutter.md, payment-architecture note (budget ≠ payments), current-milestone, progress.

**Own expenses (added 2026-10-08, user answer 5 → design A confirmed)**
9. Database: `event_expenses` (`event_id`, `title` 1–120, `amount numeric(12,2) > 0`, `currency`, `spent_on date`, optional `category_id` → `vendor_categories`, optional `note` ≤ 1000, soft delete, `version`). At most 500 per event.
10. Backend: `GET/POST /api/v1/events/{id}/expenses`, `PATCH/DELETE /api/v1/events/{id}/expenses/{expenseId}`. Owner-only (404), PLANNING-only writes (same read-only rule as the budget), `Idempotency-Key` on create, optimistic `version` on update (412), rate limited, audited without amounts or text.
11. Budget figures gain `expenses` (sum of own expenses), `spent` = paid + expenses and per-category `expenses`; `remaining` = total − committed − expenses.
12. User App: a "My expenses" section in the budget (add / edit / delete with confirmation, newest first), with exact rupee input, a date picker (default today in the device's calendar) and an optional category.

## Out of scope
- Bookings and committed amounts (M15), payment notes and paid amounts (M16), vendor discovery UI (M12), admin category management (M42).
- Notes / diary per event: **later in the roadmap** (user answer B2); a spec will be drafted when it is scheduled.
- Receipts or photos on expenses; splitting an expense across categories; currencies other than INR.
- vendor_app / admin_cms (phase-locked).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Budget tab, Home Budget overview, Menu → Budget | 4–6 |
| backend | `vendor-categories` read endpoint; `budget` module | 2–3 |
| database | `vendor_categories` (+ seed), `budget_allocations` | 1 |
| API contracts | Categories, budget endpoints | 8 |
| Notifications | Evaluated: owner's own changes, no notification | 8 |

## Acceptance criteria (Option A)
- [x] AC-1 The user can set, change and clear a planned amount per category for their event. All amounts are exact rupees end to end (`numeric(12,2)`, `"10.10"` strings, no doubles).
- [x] AC-2 The budget screen shows total, planned, unplanned and remaining, plus a clear warning when the plan exceeds the total. Sums are computed on the server and covered by tests.
- [x] AC-3 Committed and Paid show ₹0 with an honest explanation until M15/M16. Starting prices never appear in the budget.
- [x] AC-4 Another user's event returns 404. Budgets of completed and cancelled events follow the answer to open question 3. Every change is audited.
- [x] AC-5 The Home Budget overview and Menu → Budget work. They handle loading, empty, error and offline states, and render at 200 % text.
- [x] AC-6 Migrations apply, and the categories seed is idempotent. Backend and Flutter checks and tests pass.
- [x] AC-8 The user can add, edit and delete their own expenses (exact rupees, date, optional category and note). They show in the budget: Spent, Remaining and per-category figures include them; completed and cancelled events are read only.
- [x] AC-7 Security, payment (money rules), UI, performance and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Required reviews
Payment/money (exactness, rounding, separation from payments), security (ownership, input limits), UI (rupee input, warnings), performance (one budget query per event), notification (none), code review.

## Risks and assumptions
- The seeded category list becomes the starting point for vendors in M12 and admin in M42. Changing it later is an admin task (M42) or a migration.
- Committed and Paid stay ₹0 until M15/M16, so the screen may look partly empty until then. Honest copy mitigates this.

## Open questions (START issued without answers — proceeding with the proposals, 2026-10-08; the user may override before IN_REVIEW)
1. **Approach:** Option A (plan per vendor category now, fill committed and paid later; recommended), B (move Budget after M16), or C (free-text budget lines)?
2. **Starter categories:** proposed Venue, Catering, Decoration, Photography, Videography, Makeup & Mehendi, Music & DJ, Invitations & Printing, Transport, Gifts & Return Gifts, Priest & Rituals, Other services. Add, remove or rename any?
3. **Completed or cancelled events:** proposed: budget **read-only**, like the checklist (M9). OK?
4. **Total budget:** editable on the budget screen too (shortcut), or only through Edit event? Proposed: also on the budget screen.
5. **Manual expenses:** A1 says the budget only tracks platform vendors, so there are no off-platform expenses. Confirm, or should users also add their own expense lines (for example a relative's help or a non-platform vendor)?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M10 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | CONFIRMED by `START MILESTONE M11` without answers to open questions 1–5; proceeding with the spec's proposals (as in M6): **Option A**; the proposed starter category list; budget **read-only** for completed/cancelled events; total budget also editable on the budget screen; **platform vendors only** (A1, no manual expense lines). Recorded as assumptions; the user can override before IN_REVIEW | User (START) / Claude (assumptions) |
| 2026-10-08 | User answers: 1 **A**, 2 keep the starter list, 3 **read-only** for completed/cancelled, 4 total editable on the budget screen — all match the adopted proposals. Answer 5: users want to note their **own expenses** and other things "like a note pad or diary" — this reverses assumption A1 and adds scope; the concrete design (own expense entries in the budget; notes/diary) is proposed to the user for confirmation before implementation | User |
| 2026-10-08 | User confirmed design **A** ("yes"): own expense entries inside the budget (in-scope items 9–12, AC-8). Assumptions recorded: amounts > 0; at most 500 per event; expenses follow the budget's read-only rule for completed/cancelled events; a category is optional and must be a published one when set. Notes/diary: **B2 — later in the roadmap** (out of scope here). A1 is superseded for own expenses | User |
