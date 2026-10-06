# ADR-0013 — Pagination: cursor-based by default; offset for admin tables

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("use cursor for pagination is ok") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (ratifies) · Claude (proposes) |
| Supersedes | — |

## Context
Mobile lists (vendors, events, notifications, enquiries) grow and change while being scrolled; admin tables need page numbers and totals (open question 8).

## Options considered
1. **Offset everywhere** — simple; duplicates/skips under concurrent inserts, slow at large offsets.
2. **Cursor everywhere** — stable and index-friendly; admin "jump to page 7 of 20" unavailable.
3. **Cursor default, offset for admin tables** — each where it fits.

## Decision
Option 3. Cursor = opaque base64url of the sort key(s) + `id`; default `limit` 20, max 100. Admin endpoints use `page`/`pageSize` (default 25, max 100) with totals. Format in `api-contracts.md` §5.

## Consequences
- Every cursor list needs a composite index matching sort + `id`.
- Clients must treat cursors as opaque.

## Review trigger
API optimisation (M68).
