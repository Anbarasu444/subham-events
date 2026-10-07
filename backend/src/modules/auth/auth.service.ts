import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import type { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { Role } from '../rbac/roles';
import { toMeDto, type MeDto } from '../users/me.dto';
import { UsersService } from '../users/users.service';
import {
  TokenVerificationError,
  TokenVerifier,
  type VerifiedIdentity,
} from './token-verifier';

export interface RequestContext {
  requestId?: string;
  ip?: string;
}

export interface SessionResult {
  user: MeDto;
  isNewUser: boolean;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly verifier: TokenVerifier,
  ) {}

  /**
   * Maps a verified Firebase identity to the platform user (idempotent):
   * first call creates the user with role USER, audits AUTH_SIGN_UP and
   * creates the in-app welcome notification (N1, no push).
   */
  async createSession(
    identity: VerifiedIdentity,
    ctx: RequestContext,
  ): Promise<SessionResult> {
    const result = await this.dataSource.transaction(async (manager) => {
      const now = new Date();
      const { user, created } = await this.users.upsertFromIdentity(
        manager,
        {
          firebaseUid: identity.uid,
          displayName: identity.name,
          phone: identity.phone,
          email: identity.email,
          emailVerified: identity.emailVerified,
        },
        now,
      );
      if (user.status === 'SUSPENDED') {
        throw new AppException(
          ErrorCode.ACCOUNT_SUSPENDED,
          HttpStatus.FORBIDDEN,
        );
      }
      if (user.status === 'DELETED') {
        throw new AppException(ErrorCode.ACCOUNT_DELETED, HttpStatus.FORBIDDEN);
      }
      await this.users.ensureRole(manager, user.id, Role.USER);

      await this.audit.record(manager, {
        actorType: 'USER',
        actorId: user.id,
        action: created ? 'AUTH_SIGN_UP' : 'AUTH_SIGN_IN',
        entityType: 'USER',
        entityId: user.id,
        requestId: ctx.requestId,
        ip: ctx.ip,
        summary: { provider: identity.signInProvider },
      });
      if (created) {
        await this.notifications.createInApp(manager, {
          recipientUserId: user.id,
          audience: 'USER',
          category: 'AUTH',
          type: 'WELCOME',
          title: 'Welcome to Event Planner',
          body: 'Start planning your first event.',
          entityType: 'USER',
          entityId: user.id,
        });
      }
      user.roles = (await this.users.rolesOf(manager, user.id)).map((role) => ({
        userId: user.id,
        role,
        grantedAt: now,
      }));
      return { user: toMeDto(user), isNewUser: created };
    });
    this.users.invalidate(identity.uid);
    return result;
  }

  /** Revokes all refresh tokens of the caller (sign out everywhere). */
  async signOut(
    userId: string,
    firebaseUid: string,
    ctx: RequestContext,
  ): Promise<void> {
    try {
      await this.verifier.revokeRefreshTokens(firebaseUid);
    } catch (err) {
      if (
        err instanceof TokenVerificationError &&
        err.failure === 'UNAVAILABLE'
      ) {
        throw new AppException(
          ErrorCode.AUTH_PROVIDER_UNAVAILABLE,
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      }
      throw err;
    }
    await this.dataSource.transaction((manager) =>
      this.audit.record(manager, {
        actorType: 'USER',
        actorId: userId,
        action: 'AUTH_SIGN_OUT',
        entityType: 'USER',
        entityId: userId,
        requestId: ctx.requestId,
        ip: ctx.ip,
      }),
    );
  }
}
