# Event Planning Platform — Claude Project Constitution

> **This file is the single authoritative project context.**
> If any other file (rule, skill, agent, workflow, README, chat instruction from a previous session) conflicts with this file, this file wins — unless the user explicitly overrides it in the current conversation.
> There is deliberately no `.claude/CLAUDE.md`; do not create one.

---

# 1. PURPOSE

This repository is a production-grade Event Planning Platform consisting of:

- User mobile application (`user_app/`)
- Vendor mobile application (`vendor_app/`)
- Admin web CMS (`admin_cms/`)
- NestJS backend/API (`backend/`)
- PostgreSQL database (`database/`)
- Firebase services (Auth, FCM)
- Razorpay payments (vendor platform fees)
- Push + in-app notifications
- Event planning, checklist, budget, vendors, enquiries, quotations, bookings, payments, reminders, invitations and reviews

Product vision: event planning + vendor discovery + budget management + communication + booking + payment tracking + reminders + digital invitations.

## Governance file map

| Purpose | Location |
|---|---|
| Constitution (this file) | `CLAUDE.md` |
| Milestone command protocol | `START_HERE.md` |
| Detailed rules | `.claude/rules/*.md` |
| Project documentation | `.claude/project/*.md` |
| Milestone index | `.claude/project/milestones.md` |
| Milestone specs (scope + acceptance criteria) | `.claude/project/milestones/Mxx-*.md` |
| Authoritative milestone status | `.claude/project/current-milestone.md` |
| Progress log | `.claude/project/progress.md` |
| Architecture Decision Records | `.claude/project/decisions/ADR-*.md` (index: `.claude/project/decisions.md`) |
| Skills (Claude Code format) | `.claude/skills/<name>/SKILL.md` |
| Subagents (Claude Code format) | `.claude/agents/<name>.md` |
| Workflows / checklists | `.claude/workflows/*.md` |
| Claude Code permissions | `.claude/settings.json` |

---

# 2. CRITICAL GOVERNANCE RULES

These rules are mandatory.

### Rule 1 — Do not change anything without explicit permission
Do not modify, delete, rename, move, replace, recreate, or overwrite project files unless the current task explicitly authorizes the change.

When the task is unclear:
> DO NOTHING AND ASK.

### Rule 2 — Milestones are gated
Development is milestone-driven. Claude MUST NOT automatically move to the next milestone.

Claude must:
1. Work only on the currently started milestone.
2. Complete implementation.
3. Test it.
4. Perform required reviews.
5. Set the milestone to `IN_REVIEW`.
6. Report the milestone review.
7. STOP.
8. Wait for the exact approval command.

### Rule 3 — Formal milestone commands
Only these commands control milestone progression:

```text
START MILESTONE <MILESTONE_ID>
APPROVE MILESTONE <MILESTONE_ID>
```

Do NOT treat any of these as formal approval: Looks good, Good, Fine, Okay, Continue, Proceed, Great, Nice, Approved, Go ahead, Continue development, Move forward.

### Rule 4 — Approval is separate from completion
A milestone can become `IN_REVIEW` but must NOT become `COMPLETED` until `APPROVE MILESTONE <MILESTONE_ID>` is received.

After approval:
- mark the milestone `COMPLETED`
- record approval in `progress.md` and `current-milestone.md`
- identify the next milestone and set it to `NOT_STARTED`
- draft the next milestone's spec if one does not exist (spec drafting is documentation, not implementation)
- STOP

Wait for `START MILESTONE <NEXT_ID>` before doing any work on the next milestone.

### Rule 5 — No skipping milestones
Do not skip incomplete milestones. Do not combine milestones unless the user explicitly changes the governance rules.

### Rule 6 — Quality gate
A milestone is not complete merely because code compiles. Before `IN_REVIEW`, evaluate: architecture, functionality, UI/UX, error handling, security, performance, testing, documentation, notifications where applicable.

### Rule 7 — Milestone scope is vertical (cross-layer rule)
The active milestone owns **every layer required to deliver its own scope**.

- A User App milestone MAY create or modify NestJS backend code, PostgreSQL migrations, Firebase configuration, API contracts and shared documentation **when that change is required to complete that milestone's in-scope items**.
- Example: M5 Authentication may add the backend Firebase-token verification guard, the `users` table migration and the `/auth/*` endpoints, because the User App login cannot be completed without them.
- Every cross-layer change must be traceable to an in-scope item or acceptance criterion in the milestone spec and must be listed under "Files changed" in `current-milestone.md`.
- **Unrelated features remain locked.** Building backend endpoints, tables, screens or admin pages for a feature that belongs to a later milestone is forbidden, even if it is "almost free" to do now.
- **Client phase locks still apply.** Cross-layer means backend/database/Firebase/contracts — it never unlocks `vendor_app/` or `admin_cms/` UI work before their phase. If a milestone genuinely needs a change in a locked client, STOP and ask.
- Backend/database changes must follow the API contract, migration, security and notification rules exactly as if they were their own milestone.

### Rule 8 — Specs before implementation
Every milestone must have a spec at `.claude/project/milestones/Mxx-<slug>.md` containing objective, in-scope, out-of-scope, deliverables, cross-layer impact, acceptance criteria, dependencies and risks — **before** it can be started.

- Claude may draft a spec (status `DRAFT`) when asked, or at the gate after the previous milestone is approved.
- Issuing `START MILESTONE <ID>` ratifies the spec as written (status → `CONFIRMED`). The user may amend the spec before issuing the command.
- Scope changes after START require an explicit user request and are recorded in the spec's change log.
- `START MILESTONE` must be refused if no spec exists.

### Rule 9 — Governance initialization is not a milestone
Project setup/governance work (rules, skills, agents, settings, ADR structure, repository hygiene) is project infrastructure, recorded in `progress.md` as "Governance initialization". **There is no M0.** The roadmap starts at M1.

---

# 3. REPOSITORY STRUCTURE

Actual root structure:

```text
event-planning_proj/
├── CLAUDE.md            # this file — authoritative
├── START_HERE.md        # milestone command protocol
├── README.md
├── .gitignore
├── .claude/             # governance: rules, project docs, skills, agents, workflows, settings
├── user_app/            # Flutter (stock `flutter create` template) — active phase: M3–M23
├── vendor_app/          # Flutter (stock `flutter create` template) — LOCKED until M23 approved
├── admin_cms/           # Next.js 16 + Tailwind 4 scaffold (shadcn/ui not yet initialised) — LOCKED until M39 approved
├── backend/             # NestJS scaffold — modified only under Rule 7 or its own scope
└── database/            # PostgreSQL migrations/schema/seeds (empty)
```

Important:
- `user_app/` and `vendor_app/` already exist as Flutter starting templates. DO NOT recreate them. Inspect first, extend rather than replace.
- Physical existence of a folder never authorizes development in it.

---

# 4. TECHNOLOGY STACK

## User App and Vendor App
Flutter + Dart + GetX (routing, state, DI), Dio, flutter_cache_manager, cached_network_image, FreeRASP, flutter_native_splash, ObjectBox, encrypted_shared_preferences, device_info_plus, Firebase Authentication, Firebase Cloud Messaging, other Firebase services where required. Vendor App additionally uses Razorpay checkout for platform fees.

No other state-management library (Bloc, Cubit, Provider, Riverpod, Redux) without explicit approval.

## Admin CMS
Next.js, TypeScript, shadcn/ui, Tailwind CSS, responsive web UI, RBAC, production-grade admin workflows. No second component library without approval.

## Backend
NestJS (version per ADR-0003), TypeScript, REST API, PostgreSQL, Firebase Admin integration, FCM, secure authentication and authorization, validation, centralized error handling, logging, observability. The backend is explicitly NestJS, not generic Node.js.

## Database
PostgreSQL with migrations, constraints, indexes, foreign keys, transaction safety and auditability.

## Payments
Razorpay is used for Vendor platform fees. Never confuse platform fees with event/vendor payments.

---

# 5. ARCHITECTURE

```text
Client UI → GetX Controller → Repository → Service/API (Dio) / Firebase SDK
          → NestJS Controller → Service/Domain → Repository/Data access → PostgreSQL
```

- `user_app`, `vendor_app` and `admin_cms` are separate clients. They communicate only through the NestJS REST API; never couple one client's UI to another.
- PostgreSQL is the shared system of record. Firebase handles identity and push; it never replaces the domain database.
- The backend owns authoritative business rules, authorization, payment verification, notification creation and cross-client state transitions.
- UI never owns API/database/payment business logic.

---

# 6. AUTHENTICATION

Firebase Authentication is the first authentication layer for protected API access.

Login methods: Google, Phone, Guest (browse permitted public content without signing in).

Protected actions require authentication. The backend verifies Firebase ID tokens, maps identities to PostgreSQL users, and never blindly trusts client-side auth state or client-provided roles.

---

# 7. NOTIFICATIONS

Notifications are mandatory. Every meaningful user-impacting state change must be evaluated for notification delivery.

```text
Meaningful State Change → NestJS Notification Service
        ├── PostgreSQL notification record (in-app source of truth)
        └── FCM push (delivery channel)
                 → User App / Vendor App / Admin
```

Categories: AUTH, CATEGORY, VENDOR, EVENT, BOOKING, PAYMENT, CHECKLIST, INVITATION, REVIEW, SYSTEM.

Each notification identifies recipient, type, entity type/id, message, read state, creation time and deep-link metadata where useful. Avoid noisy pushes for internal technical events. See `.claude/project/notification-matrix.md`.

---

# 8. CORE DOMAIN MODEL

```text
USER → EVENT ─┬─ CHECKLIST
              └─ EVENT VENDOR ─┬─ Vendor
                               ├─ Category
                               ├─ Service / Listing
                               ├─ Agreed Budget
                               ├─ Booking
                               └─ Payments
```

A vendor listing's **starting price** is NOT the event-specific **agreed budget**. Example: Photography listing starting price ₹25,000; agreed budget for a specific event ₹40,000. The agreed budget, quotation, booking state and payment lifecycle belong to the event-vendor relationship, never only to the generic listing.

Entities (refined in M2): User, Vendor, Admin, VendorCategory, VendorListing, Event, EventVendor, ChecklistItem, Booking, Quotation, PaymentTransaction, PlatformFeeTransaction, Reminder, Invitation, Wishlist, Review, Notification, NotificationDevice, AuditLog.

---

# 9. MARKETPLACE FLOW

```text
ADMIN  creates category → sets platform fee → reviews vendor listings
VENDOR creates category listing → pays platform fee (Razorpay) → submits for review
ADMIN  approve → visible in User App | reject → vendor can resubmit
USER   browses vendor → enquiry → receives quotation → books → tracks payments
```

Admin approval is authoritative for marketplace visibility.

---

# 10. ROADMAP AND DEVELOPMENT ORDER

```text
Governance initialization (not a milestone)
M1–M2    Global Architecture, Global Domain Model
M3–M23   User App            (M23 = USER APP FREEZE)
M24–M39  Vendor App          (M39 = VENDOR APP FREEZE)
M40–M54  Admin CMS           (M54 = ADMIN CMS FREEZE)
M55–M63  Full platform integration
M64–M73  Production hardening and release
```

The full list lives in `.claude/project/milestones.md`. Do not reverse this order unless the user explicitly changes the roadmap. Backend and database have no separate phase: they evolve inside each milestone under Rule 7.

Phase locks:
- Do not start Vendor App development before M23 is completed and approved.
- Do not start Admin CMS development before M39 is completed and approved.
- Do not start integration milestones before M54 is completed and approved.

---

# 11. CROSS-PLATFORM CHANGE RULE

Every meaningful user-impacting state change must be evaluated for: database change, API change, notification (in-app + push), audit log, permissions/visibility, payment implications, affected roles/clients, and tests. Record the evaluation in the milestone review.

# 12. FEATURE GATE

For every feature: understand architecture → model/domain → repository/service → controller/business logic → UI → navigation → validation → loading/empty/error/retry → notification impact → security/performance → tests → documentation. Only then move forward.

---

# 13. MOBILE ENGINEERING RULES

Use GetX consistently: UI → Controller → Repository → Dio/API → Backend. Dependency injection via GetX bindings. Controllers must not become giant business-logic containers. Keep presentation, state, domain logic, repository/API logic and local persistence separated. Avoid unnecessary rebuilds and never block the UI thread with expensive processing.

# 14. NETWORKING RULES

Use Dio. Centralize base URL, auth headers, interceptors, request logging (where allowed), response handling, error mapping, timeouts and retry policy. No raw Dio calls in widgets. API contracts must stay synchronized with the backend.

# 15. LOCAL STORAGE

- ObjectBox — structured local data/cache that benefits from database-style persistence.
- Cache manager / cached_network_image — remote media and image caching.
- Encrypted shared preferences — small sensitive key/value data.

Never store secrets in plain text. Never treat local cache as authoritative for payments, permissions or server-owned state.

---

# 16. SECURITY

Firebase token verification on the backend; backend authorization and RBAC; input validation; secure API contracts; secure local storage; FreeRASP as defense-in-depth; device info only where required; server-side payment verification (never trust client payment success); never trust client-provided roles; no secrets in Flutter or frontend bundles (Razorpay secrets, Firebase service-account credentials, private keys, admin credentials stay server-side); secure media access; rate limiting where appropriate; audit privileged actions; protect sensitive logs.

# 17. PERFORMANCE

Target production usage and low/mid-range devices: low CPU/memory/battery, smooth scrolling, efficient network use, image caching, pagination, lazy loading, controlled rebuilds, efficient queries with appropriate indexes, no unnecessary API calls or animations, never block the UI thread. Measure before and after meaningful optimizations.

# 18. UI / UX

Modern, attractive, purposeful. Clean hierarchy, consistent spacing, accessible touch targets, responsive layouts, loading/empty/error/retry states, success feedback, confirmation for destructive actions, skeletons where useful, purposeful animations only. Mobile apps polished and production-ready; Admin CMS prioritizes information density, clarity and efficient workflows.

# 19. ERROR HANDLING

Every feature handles: loading, success, empty, error, retry, offline/network failure, unauthorized, forbidden, validation failure, server failure, timeout, stale cached data. Never leave a blank screen or unexplained failure. User-facing messages are understandable; technical detail goes to logs.

# 20. API CONTRACTS

Document endpoint, method, auth requirement, request/response shape, errors, pagination, filtering, sorting, authorization and notification side effects in `.claude/project/api-contracts.md`. When an API changes, update backend, contract docs, client repository/model/service code and tests together. Never silently break clients.

# 21. DATABASE RULES

PostgreSQL is the source of truth for server-side business data. Use migrations, foreign keys, indexes, constraints, transactions, exact numeric types for money (never floating point), timestamps, explicit status values and normalized relational structure. Avoid arbitrary JSON where a relational model fits. Every schema change is migration-driven and documented in `.claude/project/database-schema.md`.

# 22. PAYMENT RULES

Two distinct domains, always modelled separately:
- **Vendor platform fee** — vendor pays to submit/publish listings, via Razorpay: backend determines fee → creates Razorpay order → checkout → backend verifies signature/payment → records `platform_fee_transactions` → advances submission.
- **Event/vendor payment** — user pays vendor for an event booking; tracked as payment transaction records on the event-vendor/booking relationship.

Explicit states, e.g. PENDING, PROCESSING, SUCCESS, FAILED, CANCELLED, REFUNDED (refined during architecture work). Verification is always server-side. See `.claude/project/payment-architecture.md`.

# 23. MEDIA

Vendor/listing images and video, event media, profile images, invitation assets. Validate type, size, ownership and authorization on the backend (vendor individual image/video max 30 MB). Use thumbnails/resized variants, avoid loading large media unnecessarily, protect private media.

# 24. TESTING

Each milestone has appropriate unit, widget, integration, API, database, E2E, payment, notification, security and performance tests as relevant. Test success, empty, error, retry, authorization, edge cases and state transitions. Never claim completion with known failing critical tests.

---

# 25. DOCUMENTATION

Maintain under `.claude/project/`: vision, master-mindmap, architecture, domain-model, api-contracts, database-schema, notification-matrix, payment-architecture, roadmap, milestones (+ `milestones/` specs), current-milestone, progress, decisions (+ `decisions/` ADRs), known-issues. Update the relevant document whenever architecture or business decisions change. Significant decisions get an ADR.

# 26. MILESTONE STATUS FILE

`.claude/project/current-milestone.md` is authoritative and must contain: milestone ID, name, phase, status, spec link, started date, completed date, objective, completed work, in-progress work, blocked work, tests completed, security/performance/notification review status, documentation status, known issues, files changed, files pending approval, next milestone, approval status.

Allowed statuses: `NOT_STARTED`, `IN_PROGRESS`, `BLOCKED`, `IN_REVIEW`, `FAILED`, `COMPLETED`.

# 27. STANDARD MILESTONE LIFECYCLE

```text
Spec DRAFT → NOT_STARTED
   │ START MILESTONE Mx   (spec → CONFIRMED)
   ▼
IN_PROGRESS → Implementation → Testing → Security Review → Performance Review
           → Notification Review → Documentation
   ▼
IN_REVIEW
   │ APPROVE MILESTONE Mx
   ▼
COMPLETED → STOP
```

Do not automatically continue.

---

# 28. STARTUP BEHAVIOR

When Claude starts work on this repository:
1. Read this `CLAUDE.md` and `START_HERE.md`.
2. Read `.claude/project/current-milestone.md` and the active milestone's spec.
3. Read relevant `.claude/rules/` and `.claude/project/` documentation.
4. Inspect existing source files before proposing modifications.
5. Confirm the user has issued the formal start command for the active milestone.
6. Work only inside the approved milestone scope (including Rule 7 cross-layer work).

If no milestone has been formally started: do not implement features. Explain which milestone is available and wait for `START MILESTONE <MILESTONE_ID>`.

# 29. EXISTING TEMPLATES

`user_app/` and `vendor_app/` are stock Flutter templates; `admin_cms/` and `backend/` are stock framework scaffolds. Inspect them first, preserve useful configuration, avoid unnecessary rewrites, never recreate the projects, avoid unrelated changes, and explicitly report proposed structural changes before making them.

# 30. FILE CHANGE DISCIPLINE

1. Identify exact files to change. 2. Explain why when appropriate. 3. Make the smallest safe change. 4. Don't touch unrelated files. 5. Run formatting/lint/tests. 6. Report changed files. 7. Update milestone documentation. 8. Stop when ready for review.

# 31. WHEN REQUIREMENTS ARE AMBIGUOUS

Do not invent business rules. If a requirement affects money, permissions, authentication, booking state, payment state, notification behavior, database relationships, marketplace visibility or destructive operations — ask, or document the assumption before implementation. For low-risk details, choose the most maintainable conventional approach and record it.

# 32. DOMAIN PRINCIPLES

- **Event-centric**: the user's event is the central planning entity (info, checklist, budget, vendors, quotations, bookings, payments, invitations, reminders, reviews, notifications).
- **Vendor marketplace**: vendors operate through admin categories and listings, subject to admin governance.
- **Event-specific vendor relationship** stores agreed budget, booking state, quotation, payment lifecycle and event-specific status.

# 33. QUALITY BAR AND BEHAVIOR

Production quality over code volume. Prefer reuse, small focused classes, explicit contracts, safe null handling, meaningful names, no duplicated business logic, no unnecessary dependencies.

Claude behaves as a production engineering team coordinator, not a code generator. Before implementation: understand, inspect, plan, verify scope. During: preserve architecture, follow rules, focused changes, test continuously. After: validate, review security/performance/notifications, document, set `IN_REVIEW`, STOP.

# 34. FINAL RULE

> BUILD CAREFULLY, VERIFY EVERYTHING, CHANGE ONLY WITH AUTHORIZATION, COMPLETE ONE MILESTONE AT A TIME, AND STOP AT EVERY GATE.
