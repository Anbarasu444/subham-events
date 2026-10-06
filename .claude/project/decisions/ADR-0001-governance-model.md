# ADR-0001 — Governance model: root CLAUDE.md authoritative, no M0, specs before START

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |
| Milestone | Governance initialization |
| Deciders | User (directed) · Claude (implemented) |
| Supersedes | — |

## Context
Initial inspection found two constitutions (a detailed project-level CLAUDE.md held outside the repo and a short `.claude/CLAUDE.md` in it), a status file referencing a non-existent "M0", and milestones with names only and no scope or acceptance criteria.

## Options considered
1. Keep both CLAUDE files with a precedence note — risk of drift and conflicting instructions loaded together.
2. **Single root `CLAUDE.md`; `.claude/CLAUDE.md` deleted.**
3. Keep everything in `.claude/CLAUDE.md` — less discoverable; user directed root.

## Decision
- The repository root `CLAUDE.md` is the single authoritative project context. Unique content from `.claude/CLAUDE.md` (feature gate, cross-platform change rule, architecture line, mobile tech list) was merged into it, and `.claude/CLAUDE.md` is deleted (by `governance-update/apply.sh`).
- There is no M0. Governance setup is project initialization, logged in `progress.md`. The roadmap starts at M1.
- Every milestone needs a spec (`.claude/project/milestones/Mxx-*.md`) with scope and acceptance criteria before START; `START MILESTONE` ratifies the spec.

## Consequences
- One source of truth; agents and skills reference it.
- Milestone START validation gains a "spec exists" check.
- The claude.ai Project copy of CLAUDE.md is a mirror only; the repo file wins.

## Review trigger
Any proposal to add a second instruction file or change the milestone command protocol.
