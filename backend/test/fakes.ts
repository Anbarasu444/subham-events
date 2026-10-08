import {
  ImageKitClient,
  type ImageKitFile,
  type UploadParams,
  type UploadToken,
} from '../src/modules/media/imagekit.client';
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

/** In-memory ImageKit: tests put files where the app would have uploaded them. */
export class FakeImageKitClient extends ImageKitClient {
  isEnabled = true;
  readonly files = new Map<string, ImageKitFile>();
  readonly deleted: string[] = [];

  get enabled(): boolean {
    return this.isEnabled;
  }
  get publicKey(): string {
    return 'public_test';
  }
  get rootFolder(): string {
    return '/test';
  }

  readonly tokens: UploadParams[] = [];

  uploadToken(params: UploadParams): UploadToken {
    this.tokens.push(params);
    return {
      token: `jwt-${this.tokens.length}`,
      fields: {
        fileName: params.fileName,
        folder: params.folder,
        isPrivateFile: 'true',
        useUniqueFileName: 'false',
        overwriteFile: 'false',
        checks: params.checks,
      },
      expire: 2_000_000_000,
    };
  }

  findByPath(filePath: string): Promise<ImageKitFile | null> {
    return Promise.resolve(
      [...this.files.values()].find((f) => f.filePath === filePath) ?? null,
    );
  }

  /** Simulates an upload by the app. */
  put(
    file: Partial<ImageKitFile> & { fileId: string; filePath: string },
  ): void {
    this.files.set(file.fileId, {
      name: file.filePath.split('/').pop() ?? '',
      size: 1024,
      mime: 'image/jpeg',
      width: 1200,
      height: 800,
      isPrivateFile: true,
      ...file,
    });
  }

  getFile(fileId: string): Promise<ImageKitFile | null> {
    return Promise.resolve(this.files.get(fileId) ?? null);
  }

  deleteFile(fileId: string): Promise<void> {
    this.deleted.push(fileId);
    this.files.delete(fileId);
    return Promise.resolve();
  }

  signedUrl(filePath: string, transformation: string, expiresAt: Date): string {
    return `https://ik.test${filePath}?tr=${transformation}&ik-t=${Math.floor(expiresAt.getTime() / 1000)}&ik-s=signed`;
  }
}
