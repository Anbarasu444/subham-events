# Known Issues

Track known defects, limitations, workarounds and affected milestones.

| ID | Issue | Impact | Workaround / plan | Owner | Blocks |
|---|---|---|---|---|---|
| GI-1 | Remote (cloud-linked) Claude sessions are not permitted to write inside `.claude/` on the user's machine, so they cannot maintain `current-milestone.md`, `progress.md`, specs or ADRs. Governance initialization was delivered via `governance-update/apply.sh`. | Every milestone must update `.claude/project/*`; a remote session cannot. | Decide: run milestone sessions in local Claude Code (desktop Code tab / terminal), OR move `.claude/project/` to a non-hidden path (e.g. `docs/project/`) and keep only rules/skills/agents/settings in `.claude/`. | User | M1 status updates (decide before START MILESTONE M1) |
| GI-2 | `backend/.git` is an empty nested repository (no commits, no objects). Root is not yet a git repository. | Git strategy (ADR-0004) not yet executed. | With user permission: remove `backend/.git`, run `git init` at root, first commit. | project-manager | Nothing (M1 is documentation-only) |
| GI-3 | `user_app/.gitkeep` left over from the starter ZIP inside a populated Flutter project. | Cosmetic. | Remove with user permission in M3 (User App Foundation) or during GI-2. | user-app-manager | Nothing |
| GI-4 | Skill overlap: `nestjs` vs `node-api` (both NestJS REST); skill named `review` is the ratings/reviews domain and could be confused with `code-review`. | Possible wrong skill selection. | Descriptions disambiguate them now; consolidate/rename only with user approval. | architecture-manager | Nothing |
