import { CallHandler, ExecutionContext } from '@nestjs/common';
import { lastValueFrom, of } from 'rxjs';
import {
  Enveloped,
  ResponseEnvelopeInterceptor,
} from './response-envelope.interceptor';

const context = {
  switchToHttp: () => ({ getRequest: () => ({ id: 'req-12345678' }) }),
} as unknown as ExecutionContext;

const handlerOf = (value: unknown): CallHandler => ({
  handle: () => of(value),
});

describe('ResponseEnvelopeInterceptor', () => {
  const interceptor = new ResponseEnvelopeInterceptor();

  it('wraps plain results in data/meta with the request id', async () => {
    await expect(
      lastValueFrom(interceptor.intercept(context, handlerOf({ a: 1 }))),
    ).resolves.toEqual({ data: { a: 1 }, meta: { requestId: 'req-12345678' } });
  });

  it('merges extra meta such as pagination', async () => {
    const page = {
      type: 'cursor',
      limit: 20,
      nextCursor: null,
      hasMore: false,
    };
    await expect(
      lastValueFrom(
        interceptor.intercept(context, handlerOf(new Enveloped([], { page }))),
      ),
    ).resolves.toEqual({ data: [], meta: { requestId: 'req-12345678', page } });
  });

  it('leaves empty (204) responses empty', async () => {
    await expect(
      lastValueFrom(interceptor.intercept(context, handlerOf(undefined))),
    ).resolves.toBeUndefined();
  });
});
