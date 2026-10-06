# ADR-0008 — Identity and roles: Firebase (Google, phone) for users and vendors; username + password for admins; roles in PostgreSQL

| Field | Value |
|---|---|
| Status | **Accepted** — user decisions 2026-10-06 ("firebase signin (google, phone number) for client and vendors; for admin only username and password login"; "for now I don't need 2FA") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (decided) · Claude (documented the design) |
| Supersedes | — (replaces the earlier Proposed draft with Firebase Google sign-in for admins, never accepted) |

## Context
CLAUDE.md mandates Firebase Authentication (Google, phone, guest) for the apps and forbids trusting client roles. The Admin CMS needs privileged authentication and admin sub-roles.

## Decision
**Users and vendors (User App, Vendor App)**
- Firebase Authentication with **Google** and **phone number (OTP)**; guests browse public content without signing in (no anonymous Firebase users).
- The backend verifies Firebase ID tokens and maps the Firebase `uid` to a PostgreSQL `users` row. Roles `USER` / `VENDOR` live in PostgreSQL (`user_roles`); Firebase custom claims are never used for authorization.
- Google ↔ phone linking via Firebase `linkWithCredential`; no automatic merging of platform accounts.

**Admins (Admin CMS)**
- **Username + password only**, managed by the backend — no Firebase for admins. Admin accounts live in PostgreSQL `admin_users`, separate from `users`.
- Passwords hashed with **argon2id**; min length 12, common/breached-password check; lockout 15 min after 5 failed attempts; rate limiting per IP and username; generic error messages.
- **Server-side sessions**: opaque 256-bit token, stored hashed in `admin_sessions`, 8 h absolute / 30 min idle, revocable; carried by the Next.js BFF as an httpOnly `__Host-` cookie and forwarded as `Authorization: AdminSession <token>`.
- Admins are created only by a SUPER_ADMIN (temporary password, must change on first login); the first SUPER_ADMIN via an audited CLI command with credentials entered at runtime. No email-based reset at launch.
- Step-up: password re-confirmation (≤ 15 min old) for high-impact actions.
- Sub-roles: `SUPER_ADMIN`, `MARKETPLACE_ADMIN`, `FINANCE_ADMIN`, `SUPPORT_ADMIN`, `CONTENT_ADMIN`; permission matrix finalised in M40.

**Two-factor verification:** not required at launch for anyone (accepted risk; revisit in M53 Admin Hardening / M65 Security Audit).

Details: `architecture/identity-access.md`.

## Consequences
- The platform stores admin password hashes → password handling, lockout and session security become backend responsibilities and are security-review items in M40 and M65.
- Admin and app identities cannot be confused: separate tables, separate credential types, separate route groups.
- No dependency on Google accounts for admins.

## Review trigger
Admin Hardening (M53), Security Audit (M65), or any incident involving admin credentials.
