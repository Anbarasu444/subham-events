import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { RequestUser } from './request-user';
import type { VerifiedIdentity } from './token-verifier';

export interface AuthenticatedRequest {
  user?: RequestUser;
  identity?: VerifiedIdentity;
}

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): RequestUser | undefined =>
    ctx.switchToHttp().getRequest<AuthenticatedRequest>().user,
);

export const CurrentIdentity = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): VerifiedIdentity | undefined =>
    ctx.switchToHttp().getRequest<AuthenticatedRequest>().identity,
);
