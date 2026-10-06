# Event Planning Platform

Monorepo for a production-grade event planning marketplace: a User App, a Vendor App, an Admin CMS, and one shared NestJS + PostgreSQL backend.

Development is milestone-gated and driven with Claude Code. Start with `CLAUDE.md` (authoritative project context) and `START_HERE.md` (milestone commands).

## Repository structure

```text
CLAUDE.md          Authoritative project constitution
START_HERE.md      Milestone command protocol (START / APPROVE MILESTONE)
.gitignore         Root ignore rules for the whole monorepo
.claude/           Governance
  ├── settings.json   Claude Code permissions
  ├── rules/          Detailed engineering rules
  ├── project/        Architecture, domain, contracts, milestones, progress, ADRs
  ├── skills/         Claude Code skills (<name>/SKILL.md)
  ├── agents/         Claude Code subagents (<name>.md)
  └── workflows/      Checklists for recurring procedures
user_app/          Flutter User App   — stock `flutter create` template (no features yet)
vendor_app/        Flutter Vendor App — stock `flutter create` template (phase-locked until M23)
admin_cms/         Next.js 16 + Tailwind 4 scaffold, shadcn/ui not yet initialised (phase-locked until M39)
backend/           NestJS scaffold (default app module only)
database/          PostgreSQL migrations/schema/seeds (empty)
```

Dependencies are not installed in any project yet (`node_modules`, Flutter packages beyond the template).

## Technology

| Layer | Stack |
|---|---|
| User App / Vendor App | Flutter + GetX, Dio, ObjectBox, cache manager, cached_network_image, FreeRASP, native splash, encrypted_shared_preferences, device_info_plus, Firebase Auth/FCM |
| Admin CMS | Next.js + TypeScript + shadcn/ui + Tailwind CSS |
| Backend | NestJS REST API (version: see ADR-0003) |
| Database | PostgreSQL |
| Identity / Push | Firebase Authentication (Google, phone, guest browsing), FCM |
| Vendor platform fees | Razorpay (server-side order creation and verification) |

## Roadmap

There is no M0; governance setup is project initialization.

- M1–M2 Global Architecture, Global Domain Model
- M3–M23 User App (M23 freeze)
- M24–M39 Vendor App (M39 freeze)
- M40–M54 Admin CMS (M54 freeze)
- M55–M63 Integration
- M64–M73 Production hardening and release

Each milestone may change the backend and database as needed for its own scope (see `CLAUDE.md` Rule 7). Current status: `.claude/project/current-milestone.md`.

## Development lock

A folder existing does not authorize work in it. The active milestone controls what may change.
