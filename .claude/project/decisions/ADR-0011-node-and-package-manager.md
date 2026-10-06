# ADR-0011 — Node.js 24 LTS and npm for backend and Admin CMS

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("use node 24"); npm retained as used by the existing scaffolds |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (ratifies) · Claude (proposes) |
| Supersedes | — |

## Context
`backend/` and `admin_cms/` are npm-based scaffolds (scripts and `.claude/settings.json` permissions assume npm). The development machine runs Node.js v24.0.1 (observed 2026-10-06). Node 24 is the Active LTS line; Node 26 becomes LTS in late October 2026 and needs ecosystem time (open question 6).

## Options considered
1. **Node 24 LTS + npm** — current LTS, matches the dev machine and existing scaffolds and settings.
2. **Node 26 (upcoming LTS)** — longer support window; too new for NestJS 11 / Next 16 ecosystem guarantees at project start.
3. **pnpm or yarn** — faster installs and stricter dependency isolation; requires changing scaffolds, permissions and CI; little benefit with only two Node projects that do not share packages.

## Decision
**Node.js 24 LTS** (pin latest 24.x patch via `.nvmrc` + `engines` in each project, and the hosting runtime once chosen) and **npm** with committed `package-lock.json`, `npm ci` in CI. The local Node 24.0.1 should be updated to the latest 24.x patch before backend work starts (M3).

## Consequences
- No toolchain change to existing scaffolds/settings.
- Node 26 migration evaluated at M38 (before Admin CMS phase) or when Node 24 enters maintenance.

## Review trigger
Node 24 maintenance phase (Oct 2026 → Apr 2028 EOL) — plan upgrade before EOL; or a required dependency drops Node 24.
