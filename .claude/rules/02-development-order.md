# Development Order
Strict order: Governance initialization (not a milestone) → M1 Global Architecture → M2 Global Domain Model → User App (M3–M22) → User Freeze (M23) → Vendor App (M24–M38) → Vendor Freeze (M39) → Admin CMS (M40–M53) → Admin Freeze (M54) → Full Integration (M55–M63) → QA/Security/Performance/Release (M64–M73).
Future client folders may exist but are locked until their phase.

## Cross-layer rule (CLAUDE.md Rule 7, ADR-0002)
Milestones are vertical slices. The active milestone MAY change `backend/` (NestJS), `database/` (PostgreSQL migrations), Firebase configuration, API contracts and shared documentation when that change is required to complete its own in-scope items.
- Every cross-layer change must trace to an in-scope item or acceptance criterion of the active milestone spec and be listed in `current-milestone.md` → Files changed.
- Unrelated features stay locked: no endpoints, tables, screens or admin pages for later milestones.
- Cross-layer never unlocks client phase locks: no `vendor_app/` work before M23 is approved, no `admin_cms/` work before M39 is approved. If a locked client must change, STOP and ask.
- Backend/database changes follow the API contract, migration, security and notification rules in full.
