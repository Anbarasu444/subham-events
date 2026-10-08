import { plainToInstance, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
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

  /**
   * ImageKit (ADR-0007). The three keys are needed for media uploads; without
   * them the media endpoints answer 503 and the rest of the API works.
   * MEDIA_ROOT_FOLDER defaults to `/<APP_ENV>` (e.g. `/local`).
   */
  @IsOptional()
  @Matches(/^public_[A-Za-z0-9+/=_-]+$/, {
    message: 'IMAGEKIT_PUBLIC_KEY must start with public_',
  })
  IMAGEKIT_PUBLIC_KEY?: string;

  @IsOptional()
  @Matches(/^private_[A-Za-z0-9+/=_-]+$/, {
    message: 'IMAGEKIT_PRIVATE_KEY must start with private_',
  })
  IMAGEKIT_PRIVATE_KEY?: string;

  @IsOptional()
  @Matches(/^https:\/\/[A-Za-z0-9.-]+(\/[A-Za-z0-9_-]+)*$/, {
    message:
      'IMAGEKIT_URL_ENDPOINT must be an https URL without a trailing slash, e.g. https://ik.imagekit.io/your_id',
  })
  IMAGEKIT_URL_ENDPOINT?: string;

  @IsOptional()
  @Matches(/^\/[A-Za-z0-9_-]+$/, {
    message: 'MEDIA_ROOT_FOLDER must look like /local',
  })
  MEDIA_ROOT_FOLDER?: string;
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
  const imageKit = [
    validated.IMAGEKIT_PUBLIC_KEY,
    validated.IMAGEKIT_PRIVATE_KEY,
    validated.IMAGEKIT_URL_ENDPOINT,
  ];
  if (imageKit.some(Boolean) && !imageKit.every(Boolean)) {
    // Names only — never echo values (they include a secret).
    throw new Error(
      'Invalid environment configuration: set all of IMAGEKIT_PUBLIC_KEY, IMAGEKIT_PRIVATE_KEY and IMAGEKIT_URL_ENDPOINT, or none of them',
    );
  }
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
