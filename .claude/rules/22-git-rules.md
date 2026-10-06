# Git Rules
Strategy: single monorepo at the project root (ADR-0004).
- Branches: `main` is always releasable; one branch per milestone `milestone/Mxx-<slug>`; merge to `main` only after `APPROVE MILESTONE Mxx`; tag `Mxx-approved`.
- Commits: focused, Conventional Commits with an area scope (`feat(user_app)`, `feat(backend)`, `feat(database)`, `chore(governance)`, `docs(project)`); mention the milestone ID in the body.
- Never commit secrets, `.env*` (except `.env.example`), service-account files, keystores, generated credentials, local environment files or build artifacts. The root `.gitignore` plus per-project `.gitignore` files enforce this.
- Commits, pushes, branch changes and history rewrites require user permission (see `.claude/settings.json`). Never force-push `main`.
- Avoid unrelated formatting churn. Review diffs before declaring work complete.
