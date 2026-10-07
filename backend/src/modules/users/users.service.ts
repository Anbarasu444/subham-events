import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { EntityManager, Repository } from 'typeorm';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { Role } from '../rbac/roles';
import { UserRoleEntity } from './entities/user-role.entity';
import { UserEntity, UserStatus } from './entities/user.entity';

/** What the auth guard needs on every request. */
export interface UserAccess {
  id: string;
  firebaseUid: string;
  status: UserStatus;
  roles: Role[];
}

/** Verified identity attributes from Firebase — never from request bodies. */
export interface VerifiedProfile {
  firebaseUid: string;
  displayName: string | null;
  phone: string | null;
  email: string | null;
  emailVerified: boolean;
}

const ACCESS_CACHE_TTL_MS = 60_000; // identity-access.md §5: ≤ 60 s

@Injectable()
export class UsersService {
  private readonly accessCache = new Map<
    string,
    { access: UserAccess; expiresAt: number }
  >();

  constructor(
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
    @InjectRepository(UserRoleEntity)
    private readonly roles: Repository<UserRoleEntity>,
  ) {}

  /** Cached status + roles lookup for request authorization. */
  async findAccessByFirebaseUid(
    firebaseUid: string,
    now = Date.now(),
  ): Promise<UserAccess | null> {
    const cached = this.accessCache.get(firebaseUid);
    if (cached && cached.expiresAt > now) return cached.access;
    const user = await this.users.findOne({
      where: { firebaseUid },
      relations: { roles: true },
    });
    if (!user) return null;
    const access: UserAccess = {
      id: user.id,
      firebaseUid: user.firebaseUid,
      status: user.status,
      roles: (user.roles ?? []).map((r) => r.role),
    };
    this.accessCache.set(firebaseUid, {
      access,
      expiresAt: now + ACCESS_CACHE_TTL_MS,
    });
    return access;
  }

  invalidate(firebaseUid: string): void {
    this.accessCache.delete(firebaseUid);
  }

  async findById(id: string): Promise<UserEntity | null> {
    return this.users.findOne({ where: { id }, relations: { roles: true } });
  }

  /**
   * Creates the user on first sign-in or refreshes verified attributes.
   * Runs in the caller's transaction; the row is locked for update.
   */
  async upsertFromIdentity(
    manager: EntityManager,
    profile: VerifiedProfile,
    now: Date,
  ): Promise<{ user: UserEntity; created: boolean }> {
    const repo = manager.getRepository(UserEntity);
    // Serialise concurrent first sign-ins for the same identity.
    await manager.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [
      profile.firebaseUid,
    ]);
    const existing = await repo
      .createQueryBuilder('u')
      .setLock('pessimistic_write')
      .where('u.firebase_uid = :uid', { uid: profile.firebaseUid })
      .getOne();

    if (existing) {
      existing.phone = profile.phone ?? existing.phone;
      if (profile.email && profile.emailVerified) {
        existing.email = profile.email;
        existing.emailVerified = true;
      }
      existing.displayName = existing.displayName ?? profile.displayName;
      existing.lastSignInAt = now;
      return { user: await repo.save(existing), created: false };
    }

    const user = repo.create({
      id: uuidv7(),
      firebaseUid: profile.firebaseUid,
      displayName: profile.displayName,
      phone: profile.phone,
      email: profile.emailVerified ? profile.email : null,
      emailVerified: profile.emailVerified && profile.email !== null,
      status: 'ACTIVE',
      statusChangedAt: now,
      deletedAt: null,
      lastSignInAt: now,
    });
    await repo.insert(user);
    return { user, created: true };
  }

  async ensureRole(
    manager: EntityManager,
    userId: string,
    role: Role,
  ): Promise<void> {
    await manager
      .createQueryBuilder()
      .insert()
      .into(UserRoleEntity)
      .values({ userId, role })
      .orIgnore()
      .execute();
  }

  async rolesOf(manager: EntityManager, userId: string): Promise<Role[]> {
    const rows = await manager
      .getRepository(UserRoleEntity)
      .find({ where: { userId } });
    return rows.map((r) => r.role);
  }
}
