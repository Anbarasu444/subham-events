import { ExecutionContext, HttpStatus } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppException } from '../../common/errors/app.exception';
import { ROLES_KEY } from '../rbac/roles';
import type { UserAccess, UsersService } from '../users/users.service';
import {
  ALLOW_UNREGISTERED_KEY,
  CHECK_REVOKED_KEY,
  IS_PUBLIC_KEY,
} from './auth.decorators';
import { FirebaseAuthGuard } from './auth.guard';
import {
  TokenVerificationError,
  TokenVerifier,
  type VerifiedIdentity,
} from './token-verifier';

const identity: VerifiedIdentity = {
  uid: 'uid-1',
  signInProvider: 'google.com',
  phone: null,
  email: 'a@b.c',
  emailVerified: true,
  name: 'A',
  authTime: 0,
};

class StubVerifier extends TokenVerifier {
  constructor(
    private readonly outcome: VerifiedIdentity | TokenVerificationError,
  ) {
    super();
  }
  checkRevoked?: boolean;
  verify(_t: string, checkRevoked: boolean) {
    this.checkRevoked = checkRevoked;
    return this.outcome instanceof TokenVerificationError
      ? Promise.reject(this.outcome)
      : Promise.resolve(this.outcome);
  }
  revokeRefreshTokens() {
    return Promise.resolve();
  }
}

function setup(opts: {
  metadata?: Record<string, unknown>;
  header?: string;
  outcome?: VerifiedIdentity | TokenVerificationError;
  access?: UserAccess | null;
}) {
  const metadata = opts.metadata ?? {};
  const reflector = {
    getAllAndOverride: (key: string) => metadata[key],
  } as unknown as Reflector;
  const verifier = new StubVerifier(opts.outcome ?? identity);
  const users = {
    findAccessByFirebaseUid: () =>
      Promise.resolve(opts.access === undefined ? null : opts.access),
  } as unknown as UsersService;
  const req: Record<string, unknown> = {
    headers: { authorization: opts.header },
  };
  const ctx = {
    getHandler: () => undefined,
    getClass: () => undefined,
    switchToHttp: () => ({ getRequest: () => req }),
  } as unknown as ExecutionContext;
  const rateLimit = { canActivate: () => Promise.resolve(true) } as never;
  return {
    guard: new FirebaseAuthGuard(reflector, verifier, users, rateLimit),
    ctx,
    req,
    verifier,
  };
}

async function errorOf(promise: Promise<unknown>): Promise<AppException> {
  try {
    await promise;
  } catch (e) {
    return e as AppException;
  }
  throw new Error('expected rejection');
}

const active: UserAccess = {
  id: 'u1',
  firebaseUid: 'uid-1',
  status: 'ACTIVE',
  roles: ['USER'],
};

describe('FirebaseAuthGuard', () => {
  it('lets public routes through without a token', async () => {
    const { guard, ctx } = setup({ metadata: { [IS_PUBLIC_KEY]: true } });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
  });

  it('rejects a missing or non-Bearer token with AUTH_REQUIRED', async () => {
    for (const header of [undefined, 'Basic abc', 'Bearer']) {
      const { guard, ctx } = setup({ header });
      const e = await errorOf(guard.canActivate(ctx));
      expect(e.code).toBe('AUTH_REQUIRED');
      expect(e.getStatus()).toBe(HttpStatus.UNAUTHORIZED);
    }
  });

  it.each([
    ['EXPIRED', 'AUTH_TOKEN_EXPIRED', 401],
    ['REVOKED', 'AUTH_TOKEN_REVOKED', 401],
    ['INVALID', 'AUTH_TOKEN_INVALID', 401],
    ['DISABLED', 'ACCOUNT_SUSPENDED', 403],
    ['UNAVAILABLE', 'AUTH_PROVIDER_UNAVAILABLE', 503],
  ] as const)(
    'maps verifier failure %s to %s',
    async (failure, code, status) => {
      const { guard, ctx } = setup({
        header: 'Bearer t',
        outcome: new TokenVerificationError(failure),
      });
      const e = await errorOf(guard.canActivate(ctx));
      expect(e.code).toBe(code);
      expect(e.getStatus()).toBe(status);
    },
  );

  it('requires a registered user except on @AllowUnregistered routes', async () => {
    const blocked = setup({ header: 'Bearer t', access: null });
    expect((await errorOf(blocked.guard.canActivate(blocked.ctx))).code).toBe(
      'AUTH_REQUIRED',
    );

    const allowed = setup({
      header: 'Bearer t',
      access: null,
      metadata: { [ALLOW_UNREGISTERED_KEY]: true },
    });
    await expect(allowed.guard.canActivate(allowed.ctx)).resolves.toBe(true);
    expect(allowed.req.identity).toEqual(identity);
  });

  it('blocks suspended and deleted accounts', async () => {
    for (const [status, code] of [
      ['SUSPENDED', 'ACCOUNT_SUSPENDED'],
      ['DELETED', 'ACCOUNT_DELETED'],
    ] as const) {
      const { guard, ctx } = setup({
        header: 'Bearer t',
        access: { ...active, status },
      });
      const e = await errorOf(guard.canActivate(ctx));
      expect(e.code).toBe(code);
      expect(e.getStatus()).toBe(403);
    }
  });

  it('enforces required roles from the database', async () => {
    const { guard, ctx } = setup({
      header: 'Bearer t',
      access: active,
      metadata: { [ROLES_KEY]: ['VENDOR'] },
    });
    expect((await errorOf(guard.canActivate(ctx))).code).toBe('FORBIDDEN_ROLE');
  });

  it('attaches the request user and honours @CheckRevoked', async () => {
    const { guard, ctx, req, verifier } = setup({
      header: 'Bearer t',
      access: active,
      metadata: { [CHECK_REVOKED_KEY]: true },
    });
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(req.user).toEqual({
      userId: 'u1',
      firebaseUid: 'uid-1',
      roles: ['USER'],
    });
    expect(verifier.checkRevoked).toBe(true);
  });
});
