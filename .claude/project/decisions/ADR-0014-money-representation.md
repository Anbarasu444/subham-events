# ADR-0014 — Money representation: exact decimal rupees (numeric(12,2) + decimal string)

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("12A — decimal rupees") during M2 |
| Date | 2026-10-06 |
| Milestone | M1 (deferred) → resolved in M2 |
| Deciders | User (decided) · Claude (proposed) |
| Supersedes | — (earlier drafts "integer minor units" and "pending" were never accepted) |

## Context
The user wants money expressed in **rupees with decimals** (e.g. `10.10`). CLAUDE.md §21 and `.claude/rules/10-postgresql-rules.md` require exact numeric types and forbid floating point. Razorpay amounts are integer paise.

## Options considered
1. **A — exact decimal rupees.** Chosen.
2. B — floating-point double. Rejected (inexact, would need a constitution change).
3. Integer paise. Not chosen by the user.

## Decision
- **Database:** `numeric(12,2)` in **rupees** (max ₹9,999,999,999.99), plus `currency char(3) not null default 'INR'`; `CHECK (amount >= 0)` (or `> 0` where required). Never `real`, `double precision` or `money`.
- **API:** money is an object with the amount as a **decimal string with exactly 2 decimals**:
  `"agreedBudget": { "amount": "40000.00", "currency": "INR" }`. Requests must send the same form; more than 2 decimals, negative (where not allowed), exponent notation or JSON numbers → `422 VALIDATION_FAILED`.
- **Backend:** TypeORM returns `numeric` as string; repositories map it to an exact decimal type (`decimal.js` / `big.js`, chosen in M3); all arithmetic is decimal, never JS `number`. Rounding (e.g. percentage fees): half-up to 2 decimals.
- **Razorpay boundary:** the backend converts rupees → integer paise (`amount × 100`, exact) when creating orders and paise → rupees when reading provider data; paise never appear in our API or DB.
- **Clients (Flutter, Admin CMS):** keep the amount string for transport; parse to an exact decimal only when a client-side calculation is unavoidable (display totals are provided by the API); format for display as `₹40,000.00` / Indian grouping (`₹40,000` when whole) — display formatting rule finalised in M3.
- **Rates:** percentages stored as integer basis points (`fee_bps`).
- Currency: `INR` only at launch.

## Consequences
- Matches the user's "10.10 rupees" and CLAUDE.md §21.
- Every money DTO uses the same `{ amount, currency }` shape; a shared validator/transformer is built in M3.

## Review trigger
Multi-currency requirements.
