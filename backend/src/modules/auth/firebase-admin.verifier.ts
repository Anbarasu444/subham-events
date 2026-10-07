import { Injectable, Logger } from '@nestjs/common';
import {
  App,
  applicationDefault,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { AppConfigService } from '../../config/app-config.service';
import {
  TokenFailure,
  TokenVerificationError,
  TokenVerifier,
  VerifiedIdentity,
} from './token-verifier';

const FAILURE_BY_CODE: Record<string, TokenFailure> = {
  'auth/id-token-expired': 'EXPIRED',
  'auth/id-token-revoked': 'REVOKED',
  'auth/user-disabled': 'DISABLED',
  'auth/argument-error': 'INVALID',
  'auth/invalid-id-token': 'INVALID',
  'auth/user-not-found': 'INVALID',
};

/**
 * Firebase Admin SDK verifier. Credentials come from the service-account file
 * referenced by GOOGLE_APPLICATION_CREDENTIALS (kept outside the repository);
 * the app is initialised lazily so the API can boot without them.
 */
@Injectable()
export class FirebaseAdminVerifier extends TokenVerifier {
  private readonly logger = new Logger('FirebaseAuth');
  private app?: App;

  constructor(private readonly config: AppConfigService) {
    super();
  }

  async verify(
    idToken: string,
    checkRevoked: boolean,
  ): Promise<VerifiedIdentity> {
    try {
      const decoded = await getAuth(this.firebase()).verifyIdToken(
        idToken,
        checkRevoked,
      );
      const firebase = decoded.firebase as
        { sign_in_provider?: string } | undefined;
      return {
        uid: decoded.uid,
        signInProvider: firebase?.sign_in_provider ?? null,
        phone:
          typeof decoded.phone_number === 'string'
            ? decoded.phone_number
            : null,
        email: typeof decoded.email === 'string' ? decoded.email : null,
        emailVerified: decoded.email_verified === true,
        name: typeof decoded['name'] === 'string' ? decoded['name'] : null,
        authTime: decoded.auth_time,
      };
    } catch (err) {
      throw new TokenVerificationError(this.classify(err));
    }
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    try {
      await getAuth(this.firebase()).revokeRefreshTokens(uid);
    } catch (err) {
      throw new TokenVerificationError(this.classify(err));
    }
  }

  private firebase(): App {
    if (this.app) return this.app;
    this.app =
      getApps()[0] ??
      initializeApp({
        credential: applicationDefault(),
        projectId: this.config.firebaseProjectId,
      });
    return this.app;
  }

  private classify(err: unknown): TokenFailure {
    const code = (err as { code?: unknown }).code;
    if (typeof code === 'string' && code in FAILURE_BY_CODE) {
      return FAILURE_BY_CODE[code];
    }
    // Missing credentials, network or Google outage: never "invalid token".
    this.logger.warn(
      `Firebase verification unavailable (${typeof code === 'string' ? code : 'unknown'})`,
    );
    return 'UNAVAILABLE';
  }
}
