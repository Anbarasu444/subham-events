# ADR-0009 — Flutter apps: two separate codebases, no shared package

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("must always keep two code base for client and vendor") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (decided) · Claude (documented) |
| Supersedes | — (replaces the earlier Proposed draft "extract a shared package at M24", never accepted) |

## Context
`user_app` (client) and `vendor_app` (vendor) are both Flutter + GetX apps with similar infrastructure (Dio client, auth plumbing, error model, storage wrappers, design tokens). The question was whether to share code through a common Dart package.

## Options considered
1. Shared local Dart package used by both apps — not chosen.
2. **Two fully separate codebases** — each app owns all of its code. **Chosen by the user.**

## Decision
- `user_app/` and `vendor_app/` remain **two independent codebases, always**. No shared Dart package, no path dependency between them, no root `packages/` folder, no imports across the two apps.
- Both apps follow the same reference architecture (`architecture/flutter.md`) so structure and conventions stay consistent; when the Vendor App is built (M24+), it implements its own `lib/core/` following that reference — it may use `user_app` code as a reference to copy and adapt, but never depend on it.
- Behavioural consistency between apps (error codes, API contracts, money formatting) comes from the shared API contract (`api-contracts.md`), not shared code.

## Consequences
- Each app can evolve, release and be reviewed independently; the vendor app phase lock stays clean.
- Infrastructure code is duplicated; fixes to common infrastructure (e.g. the auth interceptor) must be applied to both apps — tracked in milestone specs/known issues when relevant.

## Review trigger
Only if the user changes this rule.
