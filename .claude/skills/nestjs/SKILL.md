---
name: nestjs
description: NestJS backend implementation - modules, controllers, services, DTO validation, guards, interceptors, filters, transactions, logging, payment/notification orchestration. Use for any code in backend/.
---

# NestJS Backend Skill

Use for all shared backend implementation.

## Responsibilities
- NestJS modules
- Controllers
- Services
- DTOs and validation
- Guards and authorization
- Interceptors and filters
- PostgreSQL integration
- Transactions
- REST API contracts
- Logging and error handling
- Payment and notification orchestration

## Architecture
Controller → Service/Domain → Repository/Data Access → PostgreSQL or external service.

Business logic must not live in controllers.

_Governance: read root `CLAUDE.md` and `.claude/project/current-milestone.md` first; apply only within the active milestone scope (cross-layer work per Rule 7)._
