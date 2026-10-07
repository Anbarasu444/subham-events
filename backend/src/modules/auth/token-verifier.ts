/** Identity proven by a Firebase ID token (never trusted from the client). */
export interface VerifiedIdentity {
  uid: string;
  signInProvider: string | null;
  phone: string | null;
  email: string | null;
  emailVerified: boolean;
  name: string | null;
  authTime: number;
}

export type TokenFailure =
  'EXPIRED' | 'REVOKED' | 'DISABLED' | 'INVALID' | 'UNAVAILABLE';

export class TokenVerificationError extends Error {
  constructor(readonly failure: TokenFailure) {
    super(`Token verification failed: ${failure}`);
  }
}

/** Port over Firebase Admin so the guard and tests do not depend on Google. */
export abstract class TokenVerifier {
  /** @throws TokenVerificationError */
  abstract verify(
    idToken: string,
    checkRevoked: boolean,
  ): Promise<VerifiedIdentity>;
  abstract revokeRefreshTokens(uid: string): Promise<void>;
}
