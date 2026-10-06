# ADR-0002 — Milestones are vertical slices (cross-layer rule)

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |
| Milestone | Governance initialization |
| Deciders | User (directed) · Claude (implemented) |
| Supersedes | — |

## Context
The roadmap phases are client-centric (User App → Vendor App → Admin CMS → Integration) but no milestone owns backend or database work. User App milestones such as M5 Authentication, M8 Event Management and M15 Quotations & Booking cannot be completed without NestJS endpoints, PostgreSQL migrations and Firebase configuration.

## Options considered
1. Separate backend milestones before each client phase — large speculative APIs built before their consumers exist.
2. Backend built only in the integration phase — User App would be built against mocks for 20 milestones; high rework risk.
3. **Vertical slices: each milestone owns every layer needed for its own scope.**

## Decision
An active milestone may create or modify backend (NestJS), database (PostgreSQL migrations), Firebase configuration, API contracts and shared documentation when — and only when — the change is required to complete that milestone's in-scope items. Codified as CLAUDE.md Rule 7 and `.claude/rules/02-development-order.md`.

Constraints:
- Each cross-layer change must trace to an in-scope item / acceptance criterion and be listed in `current-milestone.md` → Files changed.
- Unrelated features remain locked (no "while we're here" endpoints/tables).
- Client phase locks are unaffected: cross-layer never unlocks `vendor_app/` or `admin_cms/` before their phase.
- Backend/database work follows the API-contract, migration, security and notification rules in full.

## Consequences
- Backend and schema grow incrementally with real consumers; APIs are exercised immediately.
- Later phases (Vendor, Admin) will extend existing backend modules; contracts must be designed for multiple clients from the start (M1 API conventions).
- Milestone specs must include a "Cross-layer impact" table.

## Review trigger
If cross-layer work repeatedly dominates a client milestone, consider inserting dedicated backend milestones (requires user approval).
