import {
  CanActivate,
  ExecutionContext,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { RateLimitGuard } from '../rate-limit/rate-limit.guard';
import { ROLES_KEY, type Role } from '../rbac/roles';
import { UsersService } from '../users/users.service';
import {
  ALLOW_UNREGISTERED_KEY,
  CHECK_REVOKED_KEY,
  IS_PUBLIC_KEY,
} from './auth.decorators';
import type { AuthenticatedRequest } from './current-user.decorator';
import {
  TokenFailure,
  TokenVerificationError,
  TokenVerifier,
} from './token-verifier';

const FAILURE_TO_ERROR: Record<TokenFailure, [ErrorCode, HttpStatus]> = {
  EXPIRED: [ErrorCode.AUTH_TOKEN_EXPIRED, HttpStatus.UNAUTHORIZED],
  REVOKED: [ErrorCode.AUTH_TOKEN_REVOKED, HttpStatus.UNAUTHORIZED],
  INVALID: [ErrorCode.AUTH_TOKEN_INVALID, HttpStatus.UNAUTHORIZED],
  DISABLED: [ErrorCode.ACCOUNT_SUSPENDED, HttpStatus.FORBIDDEN],
  UNAVAILABLE: [
    ErrorCode.AUTH_PROVIDER_UNAVAILABLE,
    HttpStatus.SERVICE_UNAVAILABLE,
  ],
};

/**
 * Global guard: every route is protected unless marked @Public()
 * (identity-access.md §1). Roles and status come from PostgreSQL only.
 * Admin routes (`/admin/*`, M40) will use a separate session guard.
 */
@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly verifier: TokenVerifier,
    private readonly users: UsersService,
    private readonly rateLimit: RateLimitGuard,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const flag = (key: string) =>
      this.reflector.getAllAndOverride<boolean>(key, [
        context.getHandler(),
        context.getClass(),
      ]) === true;

    // Rate limits apply before any token work (public routes included).
    await this.rateLimit.canActivate(context);
    if (flag(IS_PUBLIC_KEY)) return true;

    const req = context
      .switchToHttp()
      .getRequest<Request & AuthenticatedRequest>();
    const token = bearerToken(req.headers.authorization);
    if (!token) {
      throw new AppException(ErrorCode.AUTH_REQUIRED, HttpStatus.UNAUTHORIZED);
    }

    try {
      req.identity = await this.verifier.verify(token, flag(CHECK_REVOKED_KEY));
    } catch (err) {
      const failure =
        err instanceof TokenVerificationError ? err.failure : 'INVALID';
      const [code, status] = FAILURE_TO_ERROR[failure];
      throw new AppException(code, status);
    }

    const access = await this.users.findAccessByFirebaseUid(req.identity.uid);
    if (!access) {
      if (flag(ALLOW_UNREGISTERED_KEY)) return true;
      throw new AppException(ErrorCode.AUTH_REQUIRED, HttpStatus.UNAUTHORIZED);
    }
    if (access.status === 'SUSPENDED') {
      throw new AppException(ErrorCode.ACCOUNT_SUSPENDED, HttpStatus.FORBIDDEN);
    }
    if (access.status === 'DELETED') {
      throw new AppException(ErrorCode.ACCOUNT_DELETED, HttpStatus.FORBIDDEN);
    }

    const required =
      this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? [];
    if (required.some((role) => !access.roles.includes(role))) {
      throw new AppException(ErrorCode.FORBIDDEN_ROLE, HttpStatus.FORBIDDEN);
    }

    req.user = {
      userId: access.id,
      firebaseUid: access.firebaseUid,
      roles: access.roles,
    };
    return true;
  }
}

function bearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const [scheme, value] = header.split(' ');
  return scheme === 'Bearer' && value ? value : null;
}
