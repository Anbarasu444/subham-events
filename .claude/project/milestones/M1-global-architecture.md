# M1 — Global Architecture

| Field | Value |
|---|---|
| Spec status | **DRAFT** — becomes CONFIRMED when the user issues `START MILESTONE M1` |
| Phase | Architecture |
| Depends on | Governance initialization complete (recorded in `progress.md`) |
| Primary owner agent | architecture-manager (with backend-, database-, security-, notification-, payment-manager as reviewers) |

## Objective
Produce the platform-wide technical architecture and the key technology decisions (as ADRs) that every later milestone builds on, so that M2 (domain model) and M3 (User App Foundation) can start without re-opening architectural questions. **Documentation and decisions only. No application feature code, no dependency installs, no migrations.**

## In scope
1. **System context & containers** — rewrite `architecture.md`: clients, NestJS API, PostgreSQL, Firebase Auth/FCM, Razorpay, object/media storage, environments; trust boundaries; data flows (diagram + text).
2. **Backend architecture** — NestJS module map (auth, users, vendors, categories, listings, events, checklist, budget, enquiries, quotations, bookings, event-payments, platform-fees, notifications, media, invitations, reviews, admin, audit); layering (controller → service/domain → repository); cross-cutting concerns: config, validation, exception filter, logging, request IDs, auth guard, RBAC guard, transactions, idempotency.
3. **API conventions** — add to `api-contracts.md`: base path and versioning (`/api/v1`), JSON naming, response envelope, error format and error codes, pagination (cursor vs offset per use), filtering/sorting, date-time (UTC ISO-8601), money representation (integer minor units + currency code), idempotency keys for payment endpoints, auth header contract, rate-limit headers.
4. **Identity & access architecture** — Firebase ID token → backend verification → PostgreSQL user mapping; guest browsing model; roles (USER, VENDOR, ADMIN sub-roles) and where they live; token refresh/expiry handling; account linking (Google ↔ phone); Admin CMS authentication approach.
5. **Data architecture conventions** — ORM / migration tool selection (ADR), naming conventions, primary-key strategy, timestamps/time zones, soft-delete policy, money type, status enums, audit-log approach, seed vs reference data, local dev DB. (Entity-level model is M2.)
6. **Flutter architecture (shared by both apps, applied per app)** — feature-first folder structure, GetX layering (bindings/controllers/repositories/services), routing and route guards (guest vs authenticated), Dio client design (interceptors, auth, error mapping, retry), result/error types, storage split (ObjectBox / encrypted prefs / cache manager), environment flavors (dev/staging/prod), FreeRASP placement, theming/design-token approach. Decision (ADR): shared Dart package vs per-app duplication.
7. **Admin CMS architecture** — App Router structure, server/client data-fetching approach, auth/session to backend, RBAC in UI vs API, shadcn/ui initialization plan (executed in M40, not now).
8. **Cross-cutting subsystems** — notification architecture (record + FCM fan-out, device registry, deep-link scheme), payment architecture (platform fee vs event payment, Razorpay order/verify/webhook flow, state machines at high level), media architecture (storage provider ADR, upload flow, size/type limits, thumbnails, private vs public), deep linking.
9. **Environments, configuration & secrets** — env matrix, secret storage approach, Firebase project-per-environment decision, `.env.example` policy, Firebase client-config file commit policy.
10. **Quality architecture** — testing strategy per layer (unit/widget/integration/API/E2E), CI baseline plan (lint/analyze/test per project), observability (structured logs, error tracking), performance budgets for mobile (startup, frame, memory) and API (p95 latency).
11. **ADRs** — one ADR per significant decision above; ratify ADR-0003 (NestJS version) and ADR-0004 (Git strategy).
12. **Milestone planning hand-off** — draft spec for M2; record recommendation on where backend/database foundation lands (proposed: M3).

## Out of scope
- Entity/table-level domain model, ERD, state machines in detail → **M2**
- Any code in `user_app/`, `vendor_app/`, `admin_cms/`, `backend/`, `database/`
- Installing/upgrading packages (incl. the NestJS upgrade itself), `flutter pub add`, `npm install`
- Creating Firebase projects, Razorpay accounts, cloud resources
- UI/visual design of screens
- Executing `git init` / removing `backend/.git` (governance follow-up GI-2, separate user decision)

## Deliverables
- Updated: `architecture.md`, `api-contracts.md` (conventions section), `payment-architecture.md`, `notification-matrix.md` (architecture section), `database-schema.md` (conventions section), `decisions.md` index
- New: `architecture/` sub-documents if needed (backend, flutter, admin, security/threat model), ADR-0006+ for each decision
- `milestones/M2-global-domain-model.md` (DRAFT)

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app / vendor_app / admin_cms | None | Documentation-only milestone |
| backend / database | None (design only) | Items 2, 5 |
| Firebase / Razorpay | None (design only) | Items 4, 8, 9 |
| `.claude/project/*` | Documentation + ADRs | All items |

## Acceptance criteria
- [ ] AC-1 `architecture.md` contains a system context diagram and container diagram covering all three clients, backend, PostgreSQL, Firebase, Razorpay and media storage, with trust boundaries marked.
- [ ] AC-2 A backend module map lists every module needed through M73, its responsibility, and allowed dependencies between modules.
- [ ] AC-3 `api-contracts.md` defines versioning, envelope, error format with an initial error-code catalogue, pagination, sorting/filtering, date/time, money, idempotency and auth-header conventions — each with a concrete JSON example.
- [ ] AC-4 The identity flow (guest → Google/phone sign-in → backend verification → user record → role resolution) is documented as a sequence diagram, including token expiry and failure paths.
- [ ] AC-5 The Flutter reference architecture specifies folder structure, layer responsibilities, routing/guard strategy, Dio design, error/result model and storage responsibilities clearly enough that M3 can be implemented without new architectural decisions.
- [ ] AC-6 Admin CMS architecture (routing, data fetching, auth, RBAC enforcement points) is documented.
- [ ] AC-7 Notification, payment and media architectures are documented, each with its happy path and failure/retry/idempotency handling, and platform-fee vs event-payment separation explicit.
- [ ] AC-8 Environment/config/secrets matrix exists; no secret is required in any client app.
- [ ] AC-9 Testing strategy, CI baseline plan, observability approach and initial performance budgets are documented.
- [ ] AC-10 Every open technology decision listed under "Open questions" is resolved by an ADR with status Accepted (user-ratified) or explicitly deferred with an owner milestone.
- [ ] AC-11 A threat-model summary (assets, actors, main threats, mitigations) is recorded and reviewed by security-manager.
- [ ] AC-12 No file outside `.claude/` (and root docs) was modified during M1; `current-milestone.md`, `progress.md` updated; milestone set to IN_REVIEW.

## Required reviews
- Security: threat model, auth/secret handling, payment verification design.
- Performance: budgets defined and architecture supports pagination/caching/lazy loading.
- Notification: architecture covers every row of the notification matrix.
- Documentation: all deliverables cross-linked, ADR index current.

## Risks and assumptions
- Assumes Firebase and Razorpay remain the chosen providers (mandated by CLAUDE.md).
- Over-design risk: decisions should stop at what M2–M5 need; later concerns may be deferred with a named owner milestone.

## Open questions (to be resolved in M1)
1. ORM / migration tool (TypeORM, Prisma, Drizzle, MikroORM, Kysely + raw migrations).
2. Media storage provider (Firebase Storage, Google Cloud Storage, AWS S3, Cloudflare R2, …).
3. Admin CMS authentication (Firebase Auth with admin custom claims vs separate credential system) and admin sub-roles.
4. Shared Dart package for user_app/vendor_app vs per-app code.
5. Hosting/deployment target for backend, database and Admin CMS.
6. Node.js LTS version and package manager (npm/pnpm) for backend and admin.
7. Firebase client-config commit policy and project-per-environment.
8. Pagination default (cursor vs offset).
9. Where backend/database foundation is built (recommendation: M3 under Rule 7).

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-06 | Initial DRAFT created during governance initialization | User (governance reconciliation) |
