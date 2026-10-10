# User App Freeze (M23)

> Status: **draft until `APPROVE MILESTONE M23`**. On approval this becomes the frozen record of the User App.

## Freeze record
| Field | Value |
|---|---|
| App | User App (`user_app/`, Flutter) |
| Version | `1.0.0+1` (user answer 4) |
| Package id | `com.example.user_app` (staging `.stg`) — **placeholder** (GI-5, fix in M72) |
| Suggested git tag | `M23-user-app-freeze` (the user commits and tags) |
| Frozen on | — (date of `APPROVE MILESTONE M23`) |
| Milestones included | M3–M23 |

### Change policy after the freeze (user answer 5)
- Allowed: bug fixes; changes needed by integration (M55–M63); release fixes (M64–M73); content/asset swaps through the one-file configs (`app_style.dart`, `app_illustrations.dart`, `config/<flavor>.json`).
- Not allowed: new User App features. New ideas go to the backlog for after release or a new milestone the user approves.
- Every post-freeze change is listed in `progress.md` with the reason.

## Feature summary (what the User App does)
- **Start & sign-in:** splash, Google and phone (OTP) sign-in, guest browsing; account restore after deletion.
- **Home:** greeting, countdown to the next event, quick-action grid, checklist progress, vendor and RSVP donut charts, budget donut, vendor suggestions, due reminders.
- **Events:** create, edit, cancel, reopen, complete, delete; cover photo; details with Overview / Checklist / Budget / Vendors tabs.
- **Checklist:** tasks with due dates, month tabs, reorder, done/undo, "Remind me".
- **Budget:** total, plan per category, own expenses, booked and paid amounts, category details page.
- **Vendors:** explore (search, filters, city), vendor details (contact for signed-in users), save, add to event, enquiry, quotes (accept/reject), booking (cancel/complete), payment notes, rating and review (+ 3-day reminder).
- **Reminders & notifications:** reminders with pushes, notification centre, push settings.
- **Invitations:** design from templates, publish, share link or picture, guest RSVP page, replies with totals.
- **Account:** profile (name, photo), my reviews, help (FAQs, contacts), settings, delete account.
- **Look:** festive theme from one style file; all pictures from one illustrations file.
- Screenshots: `user_app/test/goldens/goldens/` (Home, Home charts, Checklist, Budget, Budget details, Menu).

## Release blockers (fix in M72 unless stated) — user answer 3
| # | Blocker | Ref | Owner |
|---|---|---|---|
| 1 | Real app name and package id (now `com.example.user_app`) — also unblocks real-iPhone testing | GI-5 | User |
| 2 | Android release signing (now the debug key) | GI-11 | User + Claude |
| 3 | iOS pushes: APNs key, real bundle id | GI-35 | User |
| 4 | Sign in with Apple (App Store rule) | GI-17 | User decision |
| 5 | Separate staging and production Firebase projects | GI-18 | User |
| 6 | FreeRASP watcher e-mail and signing hashes | GI-14 | User |
| 7 | Crashlytics symbol upload | GI-22 | Claude |
| 8 | Support e-mail/phone and Terms/Privacy links | GI-38 | User |
| 9 | Final illustrations (real transparent, compressed PNGs; ₹ on budget bag) | GI-39 | User |
| 10 | Final account-deletion policy (R11) | GI-38/R11 | User |
| 11 | Hosted backend, domain and HTTPS (invitation links, DB TLS) | GI-10, M19 | User + Claude |
| 12 | Encrypted-prefs key not hardware-backed | GI-12 | Claude |
| 13 | Review comments wait for the Admin CMS moderation (M51) | GI-37 | Roadmap |
| 14 | Vendors can reply to enquiries only with the Vendor App (M32/M33) | GI-34 | Roadmap |

## Verification status
See `current-milestone.md` (M23) for evidence: regression, contrast, security and offline passes, device smoke test, iOS simulator check.
