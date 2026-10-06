import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { AppConfigService } from '../../config/app-config.service';
import { resolveRequestId } from './request-id';

/**
 * Structured JSON logging (architecture/backend.md §4).
 * The `req`/`res` serializers below drop all headers; these redact paths are
 * defence in depth in case a serializer is changed to include headers.
 */
export const REDACTED_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["idempotency-key"]',
  'req.headers["x-razorpay-signature"]',
  'res.headers["set-cookie"]',
];

@Module({
  imports: [
    LoggerModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => ({
        pinoHttp: {
          level: config.logLevel,
          genReqId: resolveRequestId,
          redact: { paths: REDACTED_PATHS, censor: '[REDACTED]' },
          customProps: () => ({ appEnv: config.appEnv }),
          serializers: {
            // Query strings may carry tokens (e.g. invitation links): log the path only.
            req: (req: { id: string; method: string; url: string }) => ({
              id: req.id,
              method: req.method,
              path: req.url.split('?')[0],
            }),
            res: (res: { statusCode: number }) => ({
              statusCode: res.statusCode,
            }),
          },
          transport:
            config.appEnv === 'local'
              ? { target: 'pino-pretty', options: { singleLine: true } }
              : undefined,
        },
      }),
    }),
  ],
})
export class LoggingModule {}
