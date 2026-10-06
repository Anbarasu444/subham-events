# NestJS Backend Rules

The shared backend is NestJS.

- Use modular NestJS architecture.
- Separate controllers, services, repositories/data access, DTOs, guards, interceptors, filters, and domain logic.
- REST API is the contract for User App, Vendor App, and Admin CMS.
- Use PostgreSQL as the primary database.
- Validate request DTOs.
- Centralize authentication and authorization.
- Never expose Razorpay secrets or Firebase service-account credentials to clients.
- Use transactions for payment, booking, approval, and other multi-step state changes where required.
- Add logging and consistent error responses.
- Do not put business logic in controllers.
