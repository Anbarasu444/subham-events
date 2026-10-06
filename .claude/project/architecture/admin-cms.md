# Admin CMS Architecture (Next.js)

> M1 deliverable for spec item 7 / AC-6. Implementation is locked until M39 is approved (M40+). Observed scaffold: Next.js 16.3.8, React 19.2.8, Tailwind 4, TypeScript 5, `src/app` App Router; shadcn/ui not yet initialised.

## 1. Role of the CMS

The CMS is a **backend-for-frontend (BFF)**: its Next.js server holds the admin session and calls the NestJS API server-side. The browser never receives API credentials beyond the httpOnly session cookie, and never calls the NestJS API directly.

## 2. Routing (App Router)

```text
src/app/
  (auth)/sign-in/page.tsx
  (auth)/change-password/page.tsx
  (auth)/access-denied/page.tsx
  (admin)/layout.tsx              # shell: sidebar, header, session check (server)
  (admin)/dashboard/page.tsx
  (admin)/categories/...          # M42
  (admin)/platform-fees/...       # M43
  (admin)/vendors/applications/...# M44–M45
  (admin)/users/...               # M46
  (admin)/events/...              # M47
  (admin)/bookings/...            # M48
  (admin)/payments/...            # M49 (platform fees and event payments shown on separate tabs)
  (admin)/notifications/...       # M50
  (admin)/content/...             # M51
  (admin)/reports/...             # M52
  api/session/route.ts            # POST create session, DELETE sign-out
src/lib/api/                      # server-only typed API client (import 'server-only')
src/lib/auth/                     # admin session cookie helpers, getAdmin()
src/lib/rbac/                     # UI permission map (mirror of backend, convenience only)
src/components/ui/                # shadcn/ui generated components (M40)
src/components/admin/             # DataTable, FilterBar, StatusBadge, ConfirmDialog, FormSheet…
```

`middleware.ts` (or the Next 16 equivalent proxy file) redirects requests without a session cookie to `/sign-in`; it does not verify the cookie cryptographically — verification happens in the layout's server call and in the API.

## 3. Data fetching

| Need | Approach |
|---|---|
| Page data | React Server Components call `src/lib/api` server-side with the session; `cache: 'no-store'` for operational data |
| Mutations | Server Actions (or route handlers) → API; on success `revalidatePath`; errors mapped to form state |
| Tables | Server-side pagination/sorting/filtering via URL search params → API offset pagination (ADR-0013) |
| Client interactivity | Client components only for interactive widgets (dialogs, forms, filters); no client-side API calls |
| Loading / error | `loading.tsx` skeletons and `error.tsx` boundaries per route segment; `not-found.tsx` |

## 4. Authentication and session

See `identity-access.md` §7 (ADR-0008). Summary: admins sign in with **username + password** on `/sign-in` (no Firebase) → the CMS server posts the credentials to `POST /api/v1/admin/auth/login` → the API verifies (argon2id, lockout, rate limits) and returns an opaque session token → the CMS sets `__Host-admin_session` (httpOnly, Secure, SameSite=Strict) → server-side API calls forward it as `Authorization: AdminSession <token>`. Sessions: 8 h absolute, 30 min idle. Pages: sign-in, forced change-password (first login / after reset), access-denied. Mutations are protected by Server Actions' origin checks plus SameSite=Strict. No Firebase SDK in the CMS.

## 5. RBAC enforcement points

| Point | Enforces | Authoritative? |
|---|---|---|
| NestJS `RolesGuard` + service policies | Every `/admin/*` route checks the admin sub-role and permission | **Yes** |
| CMS server layout | Session valid, admin active → else redirect | No (UX) |
| CMS navigation / buttons | Hide what the sub-role cannot do (`src/lib/rbac`) | No (UX) |

Backend returns `403 FORBIDDEN_PERMISSION` if UI and backend ever disagree; the CMS shows an access message. Permission matrix is finalised in M40 from the sub-roles in ADR-0008.

## 6. Audit and safety

- Every admin mutation is audited by the backend (who, sub-role, action, entity, before/after summary, request id, IP).
- Destructive or high-impact actions (reject vendor, change platform fee, refund marking, suspend user) require a confirm dialog with reason text, sent to the API and stored in the audit log.
- Platform-fee changes apply to new orders only (never retroactively) — enforced by backend.

## 7. shadcn/ui initialization plan (executed in M40, not now)

1. `npx shadcn@latest init` in `admin_cms/` (Tailwind 4 / CSS variables), base color neutral, tokens aligned with brand.
2. Add only needed primitives: button, input, form, select, dialog, sheet, table, dropdown-menu, badge, tabs, toast/sonner, skeleton, command.
3. Build composed admin components (`DataTable` on TanStack Table, `FilterBar`, `StatusBadge`, `ConfirmDialog`).
4. No second component library (rule 23).
