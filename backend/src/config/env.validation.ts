import { plainToInstance, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  validateSync,
} from 'class-validator';

export const APP_ENVS = ['local', 'staging', 'prod'] as const;
export type AppEnv = (typeof APP_ENVS)[number];

export const LOG_LEVELS = [
  'fatal',
  'error',
  'warn',
  'info',
  'debug',
  'trace',
] as const;
export type LogLevel = (typeof LOG_LEVELS)[number];

export class EnvironmentVariables {
  @IsIn(APP_ENVS)
  APP_ENV: AppEnv = 'local';

  @IsIn(['development', 'test', 'production'])
  NODE_ENV: 'development' | 'test' | 'production' = 'development';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number = 3000;

  @IsIn(LOG_LEVELS)
  LOG_LEVEL: LogLevel = 'info';

  @IsString()
  @IsNotEmpty()
  DATABASE_URL: string;

  @IsOptional()
  @IsString()
  DATABASE_MIGRATION_URL?: string;

  /** In-process scheduled jobs (event auto-complete, clean-ups). Off in tests. */
  @IsOptional()
  @IsIn(['true', 'false'])
  BACKGROUND_JOBS_ENABLED?: 'true' | 'false';

  /** Firebase project used to verify ID tokens (ADR-0012). */
  @IsOptional()
  @IsString()
  FIREBASE_PROJECT_ID?: string;
}

/**
 * Validates process environment at boot. The process must not start with
 * missing or invalid configuration (architecture/environments.md §3).
 */
export function validateEnv(
  config: Record<string, unknown>,
): EnvironmentVariables {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    const details = errors
      .map(
        (e) =>
          `${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`,
      )
      .join('; ');
    throw new Error(`Invalid environment configuration: ${details}`);
  }
  return validated;
}
