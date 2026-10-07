import { SetMetadata } from '@nestjs/common';

/** App roles stored in PostgreSQL `user_roles` (identity-access.md §2). */
export const Role = { USER: 'USER', VENDOR: 'VENDOR' } as const;
export type Role = (typeof Role)[keyof typeof Role];

export const ROLES_KEY = 'roles';

/** Requires every listed role. Roles come from PostgreSQL only, never from the client. */
export const RequireRoles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
