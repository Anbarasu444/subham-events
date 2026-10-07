import { Controller, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { getRequestId } from '../../common/logging/request-id';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { AllowUnregistered, CheckRevoked } from './auth.decorators';
import { AuthService, type SessionResult } from './auth.service';
import { CurrentIdentity, CurrentUser } from './current-user.decorator';
import type { RequestUser } from './request-user';
import type { VerifiedIdentity } from './token-verifier';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** Exchanges a Firebase ID token for the platform user (identity-access.md §4). */
  @Post('session')
  @HttpCode(HttpStatus.OK)
  @AllowUnregistered()
  @CheckRevoked()
  // Per IP; generous because mobile carrier NAT puts many users behind one IP.
  @RateLimit({ name: 'auth-session', limit: 60, windowSeconds: 60 })
  session(
    @CurrentIdentity() identity: VerifiedIdentity,
    @Req() req: Request,
  ): Promise<SessionResult> {
    return this.auth.createSession(identity, {
      requestId: getRequestId(req),
      ip: req.ip,
    });
  }

  @Post('sign-out')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit({ name: 'auth-sign-out', limit: 60, windowSeconds: 60 })
  async signOut(
    @CurrentUser() user: RequestUser,
    @Req() req: Request,
  ): Promise<void> {
    await this.auth.signOut(user.userId, user.firebaseUid, {
      requestId: getRequestId(req),
      ip: req.ip,
    });
  }
}
