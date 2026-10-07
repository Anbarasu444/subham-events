import type { Role } from '../rbac/roles';
import type { UserEntity } from './entities/user.entity';

/** The signed-in user's own profile (api-contracts.md Part B). */
export interface MeDto {
  id: string;
  displayName: string | null;
  phone: string | null;
  email: string | null;
  status: string;
  roles: Role[];
  createdAt: string;
}

export function toMeDto(user: UserEntity): MeDto {
  return {
    id: user.id,
    displayName: user.displayName,
    phone: user.phone,
    email: user.email,
    status: user.status,
    roles: (user.roles ?? []).map((r) => r.role).sort(),
    createdAt: user.createdAt.toISOString(),
  };
}
