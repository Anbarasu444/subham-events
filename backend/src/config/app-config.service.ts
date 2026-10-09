import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv, EnvironmentVariables, LogLevel } from './env.validation';

export interface ImageKitConfig {
  publicKey: string;
  /** Secret: used only for upload signatures, signed URLs and the files API. */
  privateKey: string;
  urlEndpoint: string;
  rootFolder: string;
}

/** Typed, read-only access to validated configuration. */
@Injectable()
export class AppConfigService {
  constructor(
    private readonly config: ConfigService<EnvironmentVariables, true>,
  ) {}

  get appEnv(): AppEnv {
    return this.config.get('APP_ENV', { infer: true });
  }

  get isProduction(): boolean {
    return this.appEnv === 'prod';
  }

  get port(): number {
    return this.config.get('PORT', { infer: true });
  }

  get logLevel(): LogLevel {
    return this.config.get('LOG_LEVEL', { infer: true });
  }

  get firebaseProjectId(): string | undefined {
    return this.config.get('FIREBASE_PROJECT_ID', { infer: true }) || undefined;
  }

  /** Defaults to on; tests and one-off scripts set `false`. */
  /** Public origin for invitation links, or undefined (M19). */
  get invitationBaseUrl(): string | undefined {
    return this.config.get('INVITATION_BASE_URL', { infer: true }) || undefined;
  }

  get backgroundJobsEnabled(): boolean {
    return (
      this.config.get('BACKGROUND_JOBS_ENABLED', { infer: true }) !== 'false'
    );
  }

  /** ImageKit settings, or null when media uploads are not configured. */
  get imageKit(): ImageKitConfig | null {
    const publicKey = this.config.get('IMAGEKIT_PUBLIC_KEY', { infer: true });
    const privateKey = this.config.get('IMAGEKIT_PRIVATE_KEY', { infer: true });
    const urlEndpoint = this.config.get('IMAGEKIT_URL_ENDPOINT', {
      infer: true,
    });
    const rootFolder =
      this.config.get('MEDIA_ROOT_FOLDER', { infer: true }) ||
      `/${this.appEnv}`;
    if (!publicKey || !privateKey || !urlEndpoint) return null;
    return { publicKey, privateKey, urlEndpoint, rootFolder };
  }

  get databaseUrl(): string {
    return this.config.get('DATABASE_URL', { infer: true });
  }
}
