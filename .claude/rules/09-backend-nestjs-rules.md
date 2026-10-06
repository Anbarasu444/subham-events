# NestJS Backend Rules
Backend owns authorization, business invariants, payment verification, notification creation, file validation, audit events and transactional state changes. Keep controllers thin; use modules/services/repositories. Validate all external input. Never trust client-calculated amounts or statuses.
