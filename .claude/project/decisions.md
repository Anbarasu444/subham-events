# Architecture Decisions — Index

Architecture Decision Records live in `decisions/` as `ADR-NNNN-<slug>.md`, using `decisions/_TEMPLATE.md`.

Rules:
- Number sequentially; never reuse or renumber.
- Statuses: `Proposed` → `Accepted` | `Rejected`; later `Superseded by ADR-NNNN` | `Deprecated`.
- Decisions affecting money, permissions, auth, data model, providers or versions are `Proposed` until the user ratifies them (explicit user instruction, or via a milestone START that lists the ADR for ratification).
- Accepted ADRs are not edited for substance; write a new ADR that supersedes.
- Update this index with every new or changed ADR.

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](decisions/ADR-0001-governance-model.md) | Governance model: root CLAUDE.md authoritative, no M0, specs before START | Accepted | 2026-10-06 |
| [ADR-0002](decisions/ADR-0002-cross-layer-milestone-scope.md) | Milestones are vertical slices (cross-layer rule) | Accepted | 2026-10-06 |
| [ADR-0003](decisions/ADR-0003-nestjs-version.md) | NestJS major version: 11.x | Accepted | 2026-10-06 |
| [ADR-0004](decisions/ADR-0004-git-monorepo.md) | Git strategy: single root monorepo | Accepted | 2026-10-06 |
| [ADR-0005](decisions/ADR-0005-claude-code-configuration.md) | Claude Code configuration: skills/agents format and settings.json | Accepted | 2026-10-06 |
| [ADR-0006](decisions/ADR-0006-orm-and-migrations.md) | ORM and migrations: TypeORM + migration scripts (PostgreSQL) | Accepted | 2026-10-06 |
| [ADR-0007](decisions/ADR-0007-media-storage.md) | Media storage: ImageKit.io (private files, backend-signed URLs) | Accepted | 2026-10-06 |
| [ADR-0008](decisions/ADR-0008-identity-roles-admin-auth.md) | Identity: Firebase (Google, phone) for users/vendors; admin username + password; roles in PostgreSQL; no 2FA at launch | Accepted | 2026-10-06 |
| [ADR-0009](decisions/ADR-0009-flutter-code-sharing.md) | Flutter: two separate codebases (client, vendor), no shared package | Accepted | 2026-10-06 |
| [ADR-0010](decisions/ADR-0010-hosting.md) | Hosting deferred; localhost + local PostgreSQL for now | Accepted | 2026-10-06 |
| [ADR-0011](decisions/ADR-0011-node-and-package-manager.md) | Node.js 24 LTS and npm | Accepted | 2026-10-06 |
| [ADR-0012](decisions/ADR-0012-environments-and-firebase-config.md) | Environments: staging and prod | Accepted | 2026-10-06 |
| [ADR-0013](decisions/ADR-0013-pagination.md) | Pagination: cursor by default, offset for admin tables | Accepted | 2026-10-06 |
| [ADR-0014](decisions/ADR-0014-money-representation.md) | Money: exact decimal rupees — numeric(12,2), API decimal string | Accepted | 2026-10-06 |
| [ADR-0015](decisions/ADR-0015-backend-foundation-placement.md) | Backend/database foundation built in M3 | Accepted | 2026-10-06 |
