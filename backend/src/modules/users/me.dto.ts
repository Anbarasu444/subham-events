import { Transform } from 'class-transformer';
import { IsString, IsUUID, Length, Matches } from 'class-validator';
import type { CoverDto } from '../media/media.dto';
import type { Role } from '../rbac/roles';
import type { UserEntity } from './entities/user.entity';

/** The signed-in user's own profile (api-contracts.md Part B). */
export interface MeDto {
  id: string;
  displayName: string | null;
  phone: string | null;
  email: string | null;
  /** Signed, resized URLs (M21); null without a photo. */
  photo: CoverDto | null;
  status: string;
  roles: Role[];
  createdAt: string;
}

export function toMeDto(
  user: UserEntity,
  photo: CoverDto | null = null,
): MeDto {
  return {
    id: user.id,
    displayName: user.displayName,
    phone: user.phone,
    email: user.email,
    photo,
    status: user.status,
    roles: (user.roles ?? []).map((r) => r.role).sort(),
    createdAt: user.createdAt.toISOString(),
  };
}

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value;

/** Phone and email come from sign-in and cannot be changed here. */
export class UpdateMeDto {
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  displayName: string;
}

export class SetPhotoDto {
  @IsUUID()
  mediaId: string;
}

export class DeleteAccountDto {
  /** The user types DELETE to confirm (M21). */
  @IsString()
  @Matches(/^DELETE$/, { message: 'confirm must be DELETE' })
  confirm: string;
}
