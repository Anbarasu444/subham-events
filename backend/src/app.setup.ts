import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';

export const API_PREFIX = 'api/v1';

/**
 * HTTP-level configuration shared by main.ts and e2e tests.
 * CORS stays disabled: mobile apps are not browsers and the Admin CMS calls
 * the API server-side only (architecture/backend.md §4).
 */
export function configureApp(app: INestApplication): void {
  const express = app as NestExpressApplication;
  express.useLogger(app.get(Logger));
  express.use(helmet());
  express.disable('x-powered-by');
  express.setGlobalPrefix(API_PREFIX);
  express.useBodyParser('json', { limit: '1mb' });
  express.enableShutdownHooks();
}
