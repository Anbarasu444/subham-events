import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request } from 'express';
import { map, Observable } from 'rxjs';
import { getRequestId } from '../logging/request-id';

export interface ResponseMeta {
  requestId?: string;
  [key: string]: unknown;
}

export interface Envelope<T> {
  data: T;
  meta: ResponseMeta;
}

/**
 * Handlers that already shape pagination metadata return this marker;
 * everything else is wrapped as `{ data, meta: { requestId } }`.
 */
export class Enveloped<T> {
  constructor(
    readonly data: T,
    readonly meta: Omit<ResponseMeta, 'requestId'> = {},
  ) {}
}

@Injectable()
export class ResponseEnvelopeInterceptor<T> implements NestInterceptor<
  T,
  Envelope<unknown> | undefined
> {
  intercept(
    context: ExecutionContext,
    next: CallHandler<T>,
  ): Observable<Envelope<unknown> | undefined> {
    const requestId = getRequestId(
      context.switchToHttp().getRequest<Request>(),
    );
    return next.handle().pipe(
      map((body) => {
        if (body === undefined) {
          return undefined; // 204 No Content
        }
        if (body instanceof Enveloped) {
          const enveloped = body as Enveloped<unknown>;
          return {
            data: enveloped.data,
            meta: { requestId, ...enveloped.meta },
          };
        }
        return { data: body, meta: { requestId } };
      }),
    );
  }
}
