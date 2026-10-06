# Known Issues

Track known defects, limitations, workarounds and affected milestones.

| ID | Issue | Impact | Workaround / plan | Owner | Blocks |
|---|---|---|---|---|---|
| GI-1 | ~~Remote (cloud-linked) Claude sessions are not permitted to write inside `.claude/` on the user's machine, so they cannot maintain `current-milestone.md`, `progress.md`, specs or ADRs.~~ | — | **RESOLVED 2026-10-06 — decision: Option A.** Milestone sessions run in local Claude Code (desktop Code tab / terminal), which can write `.claude/`. `.claude/project/` is not relocated. | User | Nothing |
| GI-2 | ~~`backend/.git` is an empty nested repository; root is not yet a git repository.~~ | — | **RESOLVED 2026-10-06:** `backend/.git` removed; root monorepo on `main`, commit `56a431b` "chore(governance): governance initialization and reconciliation". | project-manager | Nothing |
| GI-3 | `user_app/.gitkeep` left over from the starter ZIP inside a populated Flutter project. | Cosmetic. | Remove with user permission in M3 (User App Foundation) or during GI-2. | user-app-manager | Nothing |
| GI-4 | Skill overlap: `nestjs` vs `node-api` (both NestJS REST); skill named `review` is the ratings/reviews domain and could be confused with `code-review`. | Possible wrong skill selection. | Descriptions disambiguate them now; consolidate/rename only with user approval. | architecture-manager | Nothing |
