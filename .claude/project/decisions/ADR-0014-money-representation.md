# ADR-0014 — Money representation: rupees with 2 decimals (storage type pending)

| Field | Value |
|---|---|
| Status | **Proposed — deferred to M2** (owner milestone M2; must be resolved before any money column is created). User direction 2026-10-06: amounts in rupees with decimals, e.g. 10.10. Open point: exact decimal (Option A) vs floating-point double (Option B). |
| Date | 2026-10-06 |
| Milestone | M1 (deferred to M2) |
| Deciders | User (decides) · Claude (proposes) |
| Supersedes | — (replaces the earlier draft "integer minor units", which the user did not choose) |

## Context
The user wants money expressed in **rupees with decimals** (e.g. `10.10`), not in paise. CLAUDE.md §21 and `.claude/rules/10-postgresql-rules.md` require exact numeric types for money and forbid floating point. Razorpay amounts are integer paise.

## Options considered
1. **Option A — exact decimal rupees (recommended):** PostgreSQL `numeric(12,2)` in rupees (stores `10.10` exactly); API sends a decimal string `"10.10"` with `currency: "INR"`; backend arithmetic with an exact decimal library; Flutter/CMS display only; backend converts to integer paise only at the Razorpay boundary. Satisfies the user's "rupees like 10.10" and CLAUDE.md §21.
2. **Option B — floating-point double:** PostgreSQL `double precision` and JSON numbers parsed as `double`. `10.10` is not exactly representable; rounding errors accumulate in totals, budgets and fee calculations. Requires the user to amend CLAUDE.md §21 and the PostgreSQL rule.
3. Integer paise (earlier draft) — not chosen by the user.

## Decision
Pending the user's choice of A or B in M2. Until decided, no money column, DTO or client model may be implemented.

## Consequences
- M2's logical schema and API money shape depend on this decision.
- If B is chosen, the constitution change must be made explicitly by the user before implementation.

## Review trigger
M2 (mandatory resolution).
