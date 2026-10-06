# ADR-0004 — Git strategy: single root monorepo

| Field | Value |
|---|---|
| Status | **Proposed** — strategy defined; execution needs explicit user permission (known issue GI-2) |
| Date | 2026-10-06 |
| Milestone | Governance initialization |
| Deciders | User (ratifies) · Claude (proposes) |
| Supersedes | — |

## Context
- The project root is not a git repository.
- `backend/.git` exists from the NestJS CLI, but it is **empty**: no commits, no objects, only sample hooks. No history would be lost by removing it.
- Milestones are vertical slices (ADR-0002): one milestone commonly changes `user_app/`, `backend/`, `database/` and `.claude/project/` together, which should land as one reviewable change.

## Options considered
1. **Single monorepo at the root** — atomic cross-layer commits, one history for governance + code, one CI entry point. Needs path-filtered CI.
2. Polyrepo (one repo per app + backend) — independent release cycles, but cross-layer milestones span several repos/PRs and governance files would need a home.
3. Root repo with git submodules — the costs of both.

## Decision (proposed)
Single git monorepo at the project root.
- Remove the empty `backend/.git`; `git init` at the root; default branch `main`.
- Root `.gitignore` covers OS/IDE/secrets/Node/Flutter artifacts; per-project `.gitignore` files remain.
- Branching: `main` is always releasable; one branch per milestone `milestone/Mxx-<slug>`; optional short-lived `fix/…` branches. Merge to `main` only after `APPROVE MILESTONE Mxx`.
- Commits: focused, Conventional Commits style with scope = area, e.g. `feat(user_app): …`, `feat(backend): …`, `chore(governance): …`; reference the milestone ID in the body.
- Tags: `Mxx-approved` on the merge commit of each approved milestone; `vX.Y.Z` for releases.
- Never commit secrets, `.env*` (except `.env.example`), service-account files, keystores, build output.
- Remote hosting and CI provider: decided in M1.

## Consequences
- Cross-layer milestone changes are atomic and reviewable together.
- CI must use path filters so Flutter, Next.js and NestJS jobs run only when relevant.

## Review trigger
If an app needs an independent release cadence or separate access control.
