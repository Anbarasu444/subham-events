import {
  ArgumentsHost,
  HttpStatus,
  NotFoundException,
  PayloadTooLargeException,
} from '@nestjs/common';
import { AppException } from '../errors/app.exception';
import { ErrorCode } from '../errors/error-codes';
import { HttpExceptionFilter } from './http-exception.filter';

function hostFor(res: { status: jest.Mock; json: jest.Mock }): ArgumentsHost {
  const req = { id: 'req-12345678', path: '/x' };
  return {
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => res,
    }),
  } as unknown as ArgumentsHost;
}

function run(exception: unknown) {
  const res = { status: jest.fn(), json: jest.fn() };
  res.status.mockReturnValue(res);
  new HttpExceptionFilter().catch(exception, hostFor(res));
  return {
    status: res.status.mock.calls[0][0] as number,
    body: res.json.mock.calls[0][0] as { error: Record<string, unknown> },
  };
}

describe('HttpExceptionFilter', () => {
  it('renders AppException code, message and details', () => {
    const { status, body } = run(
      new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'eventDate',
            code: 'MUST_BE_FUTURE',
            message: 'Must be future',
          },
        ],
      ),
    );
    expect(status).toBe(422);
    expect(body.error).toEqual({
      code: 'VALIDATION_FAILED',
      message: 'Some fields are invalid.',
      details: [
        {
          field: 'eventDate',
          code: 'MUST_BE_FUTURE',
          message: 'Must be future',
        },
      ],
      requestId: 'req-12345678',
    });
  });

  it('maps framework exceptions to catalogue codes with safe messages', () => {
    const notFound = run(new NotFoundException('Cannot GET /secret/path'));
    expect(notFound.status).toBe(404);
    expect(notFound.body.error.code).toBe('NOT_FOUND');
    expect(notFound.body.error.message).not.toContain('/secret/path');

    expect(run(new PayloadTooLargeException()).body.error.code).toBe(
      'PAYLOAD_TOO_LARGE',
    );
  });

  it('hides unknown errors behind INTERNAL_ERROR', () => {
    const { status, body } = run(new Error('db password is hunter2'));
    expect(status).toBe(500);
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(JSON.stringify(body)).not.toContain('hunter2');
  });
});
