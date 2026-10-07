import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv, EnvironmentVariables, LogLevel } from './env.validation';

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

  get databaseUrl(): string {
    return this.config.get('DATABASE_URL', { infer: true });
  }
}
