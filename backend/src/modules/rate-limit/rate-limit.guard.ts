import {
  CanActivate,
  ExecutionContext,
  HttpStatus,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request, Response } from 'express';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { RateLimitStore } from './rate-limit.store';

export interface RateLimitOptions {
  /** Bucket name, e.g. `auth-session`. */
  name: string;
  limit: number;
  windowSeconds: number;
}

const RATE_LIMIT_KEY = 'rateLimit';
export const RateLimit = (options: RateLimitOptions) =>
  SetMetadata(RATE_LIMIT_KEY, options);

/**
 * Per-IP fixed-window limit for routes marked @RateLimit. Runs from the global
 * auth guard **before** token verification, so rejected or forged requests
 * still count and cannot trigger unlimited Firebase calls. Client IP relies on
 * Express `trust proxy`, which must be configured with hosting (GI-10).
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly store: RateLimitStore,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const options = this.reflector.get<RateLimitOptions | undefined>(
      RATE_LIMIT_KEY,
      context.getHandler(),
    );
    if (!options) return true;

    const http = context.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const windowMs = options.windowSeconds * 1000;
    const windowStart = new Date(Math.floor(Date.now() / windowMs) * windowMs);
    const hits = await this.store.hit(
      `${options.name}:${req.ip ?? 'unknown'}`,
      windowStart,
    );
    const reset = Math.ceil(
      (windowStart.getTime() + windowMs - Date.now()) / 1000,
    );

    res.setHeader('RateLimit-Limit', options.limit);
    res.setHeader('RateLimit-Remaining', Math.max(0, options.limit - hits));
    res.setHeader('RateLimit-Reset', reset);
    if (hits > options.limit) {
      res.setHeader('Retry-After', reset);
      throw new AppException(
        ErrorCode.RATE_LIMITED,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
