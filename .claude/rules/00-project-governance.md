# Project Governance Rules
- The repository root `CLAUDE.md` is the constitution and the single authoritative project context. `.claude/CLAUDE.md` carries no instructions.
- Read `START_HERE.md`, `.claude/project/current-milestone.md` and the active milestone spec (`.claude/project/milestones/`) before significant work.
- There is no M0. Governance setup is project initialization; the roadmap starts at M1.
- Never work outside the active milestone without explicit approval. Cross-layer work required by the active milestone is allowed (see `02-development-order.md`).
- Do not interpret existing folders as permission to develop them.
- Record significant decisions as ADRs in `.claude/project/decisions/` and update the index `.claude/project/decisions.md`.
- Keep `.claude/project/progress.md` truthful and current.
- Do not declare a milestone complete without all gates passing and the exact `APPROVE MILESTONE <ID>` command.
