# Platform Architecture
- `user_app`, `vendor_app`, and `admin_cms` are separate clients.
- Clients communicate through the NestJS API; never couple one client's UI to another.
- PostgreSQL is the shared system of record for platform business data.
- Firebase is used where appropriate for identity/push; it does not replace the domain database.
- Backend owns authoritative business rules, authorization, payment verification, and cross-client state transitions.
