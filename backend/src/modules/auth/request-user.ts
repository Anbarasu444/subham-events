import type { Role } from '../rbac/roles';

/** Authenticated caller attached to the request by the auth guard. */
export interface RequestUser {
  userId: string;
  firebaseUid: string;
  roles: Role[];
}
