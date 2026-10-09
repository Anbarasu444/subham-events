# M21 — User Profile / Menu

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M21` on 2026-10-09 (answers received 2026-10-09) |
| Phase | User App |
| Depends on | M20 COMPLETED and approved (`APPROVE MILESTONE M20`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, ui-manager, performance-manager, notification-manager, code-reviewer reviewers) |

## Context
- The Menu tab already has: Schedule, Checklist, Budget, Saved vendors, Settings (notifications), Sign out and Diagnostics (staging only).
- These entries are still "coming soon": **My profile**, **Messages** and **Help**.
- `GET /api/v1/me` returns the profile (name, phone, email, status, roles), but nothing can change it yet.
- My reviews exist on the server (`GET /me/reviews`, M20) but have no screen.
- **R11 (account deletion):** the interim rule is to only mark the account as deleted and keep the data. The final policy must be decided before this feature is built (this milestone) and at the latest before release (M72).
- **A8 (not yet confirmed):** for a deleted account:
  - sign-in is blocked and the Firebase account is disabled (not deleted);
  - a deleted vendor's listings are hidden;
  - their reviews stay visible as "Deleted user";
  - signing up again with the same Google account or phone is not possible.

## Objective (proposed)
The user can see and edit their profile, see their reviews, find help, and delete their account safely. The Menu has no dead ends.

## In scope (proposed)
**Backend and database (cross-layer, Rule 7)**
1. `PATCH /api/v1/me`: display name (1–60) and optional profile photo (question 3).
   - Phone and email come from sign-in and are read only.
   - Audited; rate limited.
2. Account deletion, `POST /api/v1/me/delete`, following R11/A8:
   - confirmation required;
   - status → DELETED and `deleted_at` set;
   - Firebase account disabled; refresh tokens revoked;
   - devices deactivated; audited.
   - Data kept (interim R11) unless question 1 decides otherwise.
3. Effects on the user's data (question 2): planning events, open enquiries, reminders and published invitations.

**User App**

4. **My profile** screen: name (editable), phone and email (read only), member since.
5. **My reviews** screen: the user's reviews, with comment status.
6. **Help** screen: FAQs about planning, vendors, payments, invitations and notifications; a contact option (question 4); app version; terms and privacy links (question 5).
7. **Delete account**:
   - explains what happens;
   - asks the user to type DELETE to confirm;
   - signs out after deleting.
8. Menu cleanup: hide or keep "Messages" as "coming soon" (question 6); guest view of the Menu.

## Out of scope
- Messaging/chat (no milestone yet; question 6).
- Vendor profile (Vendor App), admin user management (M46).
- Data export (unless question 1 asks for it).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Profile, My reviews, Help, Delete account, Menu | 4–8 |
| backend | `PATCH /me`, `POST /me/delete`, side effects | 1–3 |
| database | Possibly a profile photo column; no destructive change | 1–3 |
| Firebase | Admin SDK: disable user, revoke tokens | 2 |
| API contracts | `/me` changes | 1–2 |
| Notifications | Probably none (account changes are the user's own actions); evaluated in review | — |

## Acceptance criteria
- [x] AC-1 The user can edit their name and see their profile. Phone and email are read only. Changes are validated, audited and rate limited. — Evidence: e2e "edits the name; phone and email cannot be changed"; app tests (controller + My profile screen). Profile photo too (e2e "sets, replaces and removes a profile photo", app photo tests, config switch test).
- [x] AC-2 *(amended by answers 1A, 2A, 7A)* Account deletion follows the decided R11/A8 policy: typed confirmation, tokens revoked, devices off, every API call refused afterwards, data kept, the decided effects (bookings, events, reminders, invitations), and **signing in again restores the account** (Firebase is not disabled). — Evidence: e2e "deletes the account, cancels its plans and restores on sign-in"; app delete-flow tests.
- [x] AC-3 My reviews and Help work with every state. No Menu entry is a dead end without explanation. — Evidence: My reviews list/empty tests, Help test (FAQs, contacts, version, coming-soon legal), shell test "menu sections open real pages; no Coming soon left"; Messages hidden.
- [x] AC-4 All screens render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW. — Evidence: 200 % test; backend 74 + 148, Flutter 313; Android build not re-run (disk full — see current-milestone.md).

## Risks
- Deletion is irreversible for the user under A8, so the confirmation and explanation must be very clear.
- Firebase Admin calls need the service account on the server. Disable and revoke are tested with the fake verifier; a real run is the user's step.

## Open questions (please answer before `START MILESTONE M21`)
1. **R11 final deletion policy**, needed now. Pick one:
   - A: keep the interim rule. Mark as deleted, keep all data, disable sign-in. *(simplest; recommended for now, revisit before M72)*
   - B: anonymise personal data (name, phone, email → removed) but keep events, bookings and reviews anonymised for the vendors' records.
   - C: delete the user's personal data and events after a grace period (e.g. 30 days, can cancel by contacting support).
2. **What happens to the user's things on deletion:**
   - planning events are cancelled (vendors with open enquiries are told);
   - reminders are cancelled;
   - invitation links are turned off;
   - confirmed bookings are cancelled with reason "Account deleted" (the vendor is notified).
   OK, or should deletion be refused while there are confirmed bookings?
3. **Profile photo:** add one now (ImageKit upload like the event cover), or name only for now?
4. **Help contact:** an email address for support (which one?), WhatsApp, or FAQs only for now?
5. **Terms & privacy:** do you have links yet? If not, I'll show "coming soon" and track it for release.
6. **Messages:** keep it in the Menu as "coming soon", or hide it until a chat milestone exists?
7. **A8:** confirm the rest: sign-in blocked, a deleted vendor's listings hidden, reviews stay as "Deleted user", and the same Google account or phone can't sign up again.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-09 | Initial DRAFT created at the M20 approval gate | CLAUDE.md Rule 4 |
| 2026-10-09 | User answers: 1 **A** — R11 final policy for now: mark deleted, keep all data (revisit before M72); 2 **A** — accept the proposed effects (planning events cancelled, reminders cancelled, invitation links turned off, confirmed bookings cancelled with reason "Account deleted" and the vendor told); 3 **add a profile photo**, with a switch so the user can hide the feature later; 4 Help contact **placeholder** email `test@gmail.com` and phone `1234554321`, kept in configuration so they can be changed later; 5 terms/privacy **coming soon** (tracked for release); 6 **hide Messages** until a chat milestone; 7 **changes A8: a deleted user can sign in again** — exact behaviour (restore the old account or start fresh) pending one follow-up question | User |
| 2026-10-09 | CONFIRMED by `START MILESTONE M21`. The follow-up on answer 7 was not answered → **assumption: option A** (signing in again restores the old account; its cancelled events stay cancelled). Documented per CLAUDE.md §31; the user can switch to B before approval | User / Claude |
| 2026-10-09 | User confirmed follow-up 7 = **A**: signing in again restores the old account (cancelled events stay cancelled). A8 updated accordingly | User |
| 2026-10-09 | Implemented; AC-2 wording amended to the user's answers (no Firebase disable; restore on sign-in). Set IN_REVIEW | Claude |
