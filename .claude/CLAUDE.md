# Event Planning Platform — Claude Project Constitution

## Mission
Build a production-grade event planning marketplace with three applications and one shared backend platform:
- `user_app/` — Flutter User App
- `vendor_app/` — Flutter Vendor App
- `admin_cms/` — Next.js + shadcn/ui Admin CMS (Next.js + shadcn/ui)
- `backend/` — NestJS REST API
- `database/` — PostgreSQL schema, migrations and seeds

## Development order — absolute
1. Project governance and global architecture
2. User App — complete and freeze
3. Vendor App — complete and freeze
4. Admin CMS (Next.js + shadcn/ui) — complete and freeze
5. Full cross-platform integration
6. Security, performance, QA and production release

Do not skip, merge, or reorder these phases without explicit user approval.

## Existing application templates
`user_app/` and `vendor_app/` are pre-created Flutter projects. Inspect them before modifying. Never recreate or overwrite them blindly. Preserve existing configuration and working functionality.

## Technology mandates
Flutter/Dart + GetX for both mobile apps. Required mobile foundation: Dio, ObjectBox, cache manager, cached_network_image, FreeRASP, native splash, encrypted_shared_preferences, device_info_plus, Firebase where appropriate. Admin is Next.js. Backend is NestJS REST. Database is PostgreSQL. Firebase Auth handles Google/phone identity; guest users may browse but protected actions require authentication. Razorpay handles vendor platform-fee checkout; secrets stay server-side. FCM is the push channel and PostgreSQL is the in-app notification source of truth.

## Architecture
UI → GetX Controller → Repository → Service/API/Firebase → Backend → PostgreSQL. UI never owns API/database/payment business logic. Shared business state belongs to backend/domain contracts, not another app's UI.

## Domain anchors
User → Event → EventVendor → Booking → Payment transactions.
Vendor → Admin Category → Vendor Listing → Platform Fee → Review → User Marketplace.
Vendor listing starting price is different from event-specific agreed budget.
Platform-fee transactions and event/vendor payment records are separate domains.

## Cross-platform change rule
Every meaningful user-impacting state change must be evaluated for database change, API change, notification, push, audit log, permissions/visibility, payment implications, affected roles, and tests.

## Feature gate
For every feature: understand architecture → model/domain → repository/service → controller/business logic → UI → navigation → validation → loading/empty/error/retry → notification impact → security/performance → tests → documentation. Only then move forward.

## Quality bar
Production quality over code volume. Prefer reuse, small focused classes, explicit contracts, safe null handling, meaningful names, no duplicated business logic, and no unnecessary dependencies.

## Security
Never put API secrets, Firebase service-account credentials, Razorpay secrets, private keys, or admin credentials in client apps. Validate authorization and payment state on the backend.

## Milestones
A milestone is complete only when architecture, functionality, UI/UX, tests, security, performance, documentation, and review gates pass. Claude must stop at the milestone gate and wait for user approval before starting the next major milestone.

## Current starting point
Start at `M0 — Project Governance`. After governance is established, work through global architecture and then the User App only.
