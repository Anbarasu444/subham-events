# ADR-0005 — Claude Code configuration: skills/agents format and settings.json

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |
| Milestone | Governance initialization |
| Deciders | User (directed) · Claude (implemented) |
| Supersedes | — |

## Context
- The 42 skills had a `SKILL.md` with no YAML frontmatter, so Claude Code saw only a heading as their description and could not decide when to use them.
- The 14 agents had no frontmatter, so they were not registered as subagents, and their bodies were one-line role statements.
- There was no `.claude/settings.json`, so the "change nothing without permission" rule and the secrets rules were enforced by instructions only.

## Decision
1. **Skills** — every `.claude/skills/<name>/SKILL.md` starts with frontmatter `name` (equal to the folder name) and `description` (what it covers and when to use it, incl. phase notes). Skill bodies were kept; names were not changed (GI-4 tracks possible consolidation).
2. **Agents** — every `.claude/agents/<name>.md` has frontmatter `name`, `description` and, for review-only agents, a read-only `tools` list. Bodies are full system prompts: read root `CLAUDE.md` and `current-milestone.md` first, respect phase locks and Rule 7, stay within ownership.
3. **settings.json is needed** and is committed:
   - `allow`: read-only git commands, analyze/lint/test/build commands.
   - `ask`: commits, pushes, branch operations, dependency changes, `rm`/`mv`, database CLI, Firebase CLI.
   - `deny`: reading/editing secret files (`.env`, keys, keystores, service accounts), `rm -rf`, force-push, `git reset --hard`, `git clean`, project re-creation (`flutter create`, `create-next-app`, `nest new`), `npm publish`, `dropdb`.
   - Personal overrides go in `.claude/settings.local.json` (git-ignored).
4. Hooks that enforce milestone scope automatically are **not** added yet; revisit in M1 if needed.

## Consequences
- Skills can be selected on their descriptions; agents can be delegated to.
- Some legitimate commands will prompt for permission; this is intentional.
- Deny rules are a backstop, not a replacement for the governance rules.

## Review trigger
When the toolchain (pnpm, Prisma CLI, etc.) is chosen in M1, update the allow/ask lists.
