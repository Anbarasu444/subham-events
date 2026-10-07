import {
  TokenVerificationError,
  TokenVerifier,
  type TokenFailure,
  type VerifiedIdentity,
} from '../src/modules/auth/token-verifier';

/** Tokens are "<uid>" or "fail:<FAILURE>"; no Firebase involved. */
export class FakeTokenVerifier extends TokenVerifier {
  readonly revoked: string[] = [];
  readonly checkRevokedCalls: boolean[] = [];
  identities = new Map<string, Partial<VerifiedIdentity>>();

  verify(token: string, checkRevoked: boolean): Promise<VerifiedIdentity> {
    this.checkRevokedCalls.push(checkRevoked);
    if (token.startsWith('fail:')) {
      return Promise.reject(
        new TokenVerificationError(token.slice(5) as TokenFailure),
      );
    }
    const extra = this.identities.get(token) ?? {};
    return Promise.resolve({
      uid: token,
      signInProvider: 'phone',
      phone: '+919800000001',
      email: null,
      emailVerified: false,
      name: null,
      authTime: Math.floor(Date.now() / 1000),
      ...extra,
    });
  }

  revokeRefreshTokens(uid: string): Promise<void> {
    this.revoked.push(uid);
    return Promise.resolve();
  }
}
