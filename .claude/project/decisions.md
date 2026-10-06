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
