# Threat Model Summary

> M1 deliverable for AC-11. STRIDE-oriented summary at architecture level; refined per feature in each milestone's security review and fully audited in M65.

## 1. Assets

| ID | Asset | Sensitivity |
|---|---|---|
| A1 | User identities & PII (name, phone, email, profile photo) | High |
| A2 | Event data (dates, venues, guest-related details, budgets) | Medium–High |
| A3 | Vendor business data, listings, unpublished media | Medium |
| A4 | Money records: platform-fee transactions, event payment records, quotations, agreed budgets | High (integrity) |
| A5 | Razorpay key secret, webhook secret, ImageKit private key, DB credentials, Firebase Admin credentials | Critical |
| A6 | Admin accounts, password hashes, admin sessions and sub-roles | Critical |
| A7 | Marketplace visibility (approval state) | High (integrity) |
| A8 | Notification channel (FCM tokens, push content) | Medium |
| A9 | Audit log | High (integrity) |
| A10 | Invitation share tokens & public invitation pages | Medium |

## 2. Actors

| Actor | Capability |
|---|---|
| Guest / anonymous internet user | Calls public endpoints, opens invitation links, scripted scraping |
| Authenticated user | Valid Firebase token; may tamper with app/requests |
| Authenticated vendor | Same, plus vendor routes; financial motive to bypass platform fees or approval |
| Malicious admin / compromised admin account | Privileged routes |
| Attacker with a compromised/rooted device or repackaged app | Can read app storage, hook code, replay requests |
| Network attacker | Passive/active MITM on hostile networks |
| Third-party provider incident | Razorpay/Firebase outage or spoofed callbacks |

## 3. Main threats and mitigations

| # | Threat (STRIDE) | Target | Mitigation | Where |
|---|---|---|---|---|
| T1 | Spoofing: forged or replayed tokens; client-asserted roles | A1, A6 | Firebase token verification server-side (signature, audience=project, issuer, expiry; revocation check on sensitive routes); roles only from PostgreSQL | identity-access.md |
| T2 | Elevation via IDOR: accessing another user's event/booking/enquiry by ID | A2, A3, A4 | Ownership policy in every service; 404 on not-owned; authZ e2e matrix tests per resource. UUIDv7 IDs make enumeration harder but are **not** a security control (partly time-ordered) | backend.md §2, quality.md |
| T3 | Tampering with money: client-supplied amounts, fee bypass, fake payment success | A4, A7 | Amount always computed server-side from DB; Razorpay order created server-side; signature verification (HMAC-SHA256) + webhook confirmation; idempotency keys; submission advances only on verified SUCCESS | payment-architecture.md |
| T4 | Webhook spoofing / replay | A4 | Verify `X-Razorpay-Signature` with webhook secret on raw body; dedupe by event id; reconcile via Razorpay API fetch | payment-architecture.md |
| T5 | Secret disclosure from clients or repo | A5 | No secrets in clients (environments.md); `.gitignore` + Claude deny rules; gitleaks in CI; secrets only in git-ignored local `.env` / service-account file outside the repo now, hosted secret store later | environments.md |
| T6 | Admin account takeover (password guessing, credential stuffing, stolen session) / insider abuse | A6, A7, A9 | Username + password with argon2id hashing, 12+ char and breached-password checks, lockout after 5 failures, per-IP/per-username rate limits, generic errors; opaque server-side sessions stored hashed, httpOnly `__Host-` cookie held by the BFF, 8 h absolute / 30 min idle, revocable; admin routes accept only admin sessions; step-up password confirmation for high-impact actions; sub-role least privilege; reason required for high-impact actions; append-only audit log incl. login success/failure. **No 2FA at launch — accepted risk by user decision, revisit M53/M65** | identity-access.md §7, admin-cms.md |
| T7 | Malicious uploads (oversized, wrong type, polyglot, EXIF location leak, SVG XSS) | A3, A1 | Single-use ImageKit upload auth with folder/name/privacy fixed by the API; backend verifies path, size and type via the ImageKit API after upload and deletes invalid files; 30 MB vendor limit; metadata stripped in delivered variants; SVG not accepted from users/vendors; all files private, delivered via backend-signed URLs; ImageKit private key server-side only; malware scanning evaluated in M65 | media-and-deep-links.md |
| T8 | Data exposure via public endpoints (unapproved listings, PII in vendor/review responses) | A3, A1 | Public DTOs separate from owner DTOs; visibility filter (approved only) in repository queries; review author shown by display name only | backend.md |
| T9 | Abuse / DoS: OTP pumping, enquiry spam, upload-intent flooding, scraping | All | Firebase phone-auth abuse protections, SMS region allow-list (India) and App Check; backend verification of App Check tokens on public and upload-intent endpoints evaluated in M22; shared-store rate limits per IP/user per route bucket; edge protection with the hosting ADR; pagination caps (max page size 100) | backend.md §4 |
| T10 | Repackaged / rooted client, local storage theft | A1, A8 | Encrypted prefs for sensitive values; no secrets on device; FreeRASP detection as defense-in-depth; backend never trusts client state | flutter.md §7, §10 |
| T11 | MITM | A1, A4 | HTTPS only (HSTS on web), no cleartext traffic in release builds; certificate pinning evaluated in M22 (operational cost vs benefit) | flutter.md |
| T12 | Notification leakage on lock screen / to wrong device | A8, A2 | Push bodies contain no sensitive amounts/PII beyond a short summary; device tokens bound to user and removed on sign-out; recipient computed server-side | notification-matrix.md |
| T13 | Invitation link guessing | A10 | 128-bit random tokens; revocable; rate-limited public endpoint; no PII beyond what the host chose to publish | media-and-deep-links.md §5 |
| T14 | Repudiation of privileged actions | A9 | Audit log with actor, sub-role, request id, IP, timestamp; tamper-evident (append-only, no DELETE grants) | backend.md |
| T15 | Sensitive data in logs | A1, A5 | Structured logger redaction list; no request bodies logged for auth/payment routes; log access restricted | quality.md §3 |
| T16 | Injection (SQL, header, template) | All | Parameterised queries via ORM/query builder only; DTO whitelisting; output encoding in CMS (React default) | backend.md |
| T17 | Software supply chain: malicious/compromised npm or pub dependency, CI credential theft | All | Committed lockfiles, `npm ci`, dependency audit in CI, minimal dependencies (CLAUDE.md §33), Dependabot/renovate review, CI OIDC instead of long-lived keys, gitleaks | quality.md §2, environments.md §3 |
| T18 | Backup / PITR data exposure | A1–A4 | Encrypted managed backups, same region, operator-only restore, audited restores | environments.md §3 |
| T19 | Vendor-to-user fraud / abuse: fake reviews, scams via enquiries, off-platform payment pressure | A2, A4, A7 | Reviews only after a completed booking; report/flag on vendors, reviews and enquiries; moderation in Admin CMS; admin suspension with audit | M20, M44–M51 |
| T20 | Malicious media processing (decompression bombs, parser exploits) | Media pipeline | No media processing on our servers — transformations run inside ImageKit; backend only reads file metadata via API; SVG not accepted | media-and-deep-links.md §3 |

## 4. Residual risks / follow-ups

| Item | Owner milestone |
|---|---|
| Malware scanning for uploads | M65 |
| Certificate pinning decision | M22 |
| Admin permission matrix detail | M40 |
| Account-merge support process (Google ↔ phone conflicts) | M21 or later, if requested |
| **Account deletion keeps all data (R11 — interim development rule; final policy to be discussed, owner M21)** — conflicts with DPDP Act 2023 erasure rights and Google Play / App Store account-deletion requirements; legal review or switch to anonymisation needed before release | M72 (blocking for store release) |
| Penetration test | M65 |
| Admin two-factor verification (not required at launch by user decision) | M53 / M65 |
