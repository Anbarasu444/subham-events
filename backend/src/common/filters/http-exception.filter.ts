import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { AppException, ErrorDetail } from '../errors/app.exception';
import { DEFAULT_MESSAGES, ErrorCode } from '../errors/error-codes';
import { getRequestId } from '../logging/request-id';

export interface ErrorEnvelope {
  error: {
    code: ErrorCode;
    message: string;
    details: ErrorDetail[];
    requestId?: string;
  };
}

const STATUS_TO_CODE: Partial<Record<number, ErrorCode>> = {
  [HttpStatus.BAD_REQUEST]: ErrorCode.BAD_REQUEST,
  [HttpStatus.UNAUTHORIZED]: ErrorCode.AUTH_REQUIRED,
  [HttpStatus.FORBIDDEN]: ErrorCode.FORBIDDEN_PERMISSION,
  [HttpStatus.NOT_FOUND]: ErrorCode.NOT_FOUND,
  [HttpStatus.METHOD_NOT_ALLOWED]: ErrorCode.NOT_FOUND,
  [HttpStatus.CONFLICT]: ErrorCode.CONFLICT,
  [HttpStatus.PRECONDITION_FAILED]: ErrorCode.PRECONDITION_FAILED,
  [HttpStatus.PAYLOAD_TOO_LARGE]: ErrorCode.PAYLOAD_TOO_LARGE,
  [HttpStatus.UNPROCESSABLE_ENTITY]: ErrorCode.VALIDATION_FAILED,
  [HttpStatus.TOO_MANY_REQUESTS]: ErrorCode.RATE_LIMITED,
  [HttpStatus.SERVICE_UNAVAILABLE]: ErrorCode.SERVICE_UNAVAILABLE,
};

/**
 * Express body-parser errors (e.g. body too large) are plain errors carrying a
 * 4xx `status` and a `type` such as `entity.too.large`.
 */
function bodyParserErrorStatus(exception: unknown): number | undefined {
  if (typeof exception !== 'object' || exception === null) return undefined;
  const { status, type } = exception as { status?: unknown; type?: unknown };
  return typeof type === 'string' &&
    type.startsWith('entity.') &&
    typeof status === 'number' &&
    status >= 400 &&
    status < 500
    ? status
    : undefined;
}

/**
 * Renders every error as the API error envelope (api-contracts.md §4).
 * Unknown errors become INTERNAL_ERROR; their details are logged, never returned.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const requestId = getRequestId(req);

    const { status, code, message, details } = this.describe(exception);

    if (status >= 500) {
      if (exception instanceof AppException) {
        // Expected, classified failure (e.g. dependency down): no stack needed.
        this.logger.warn({ code, requestId, path: req.path }, message);
      } else {
        // Log name/message/stack only: driver errors carry query parameters
        // (personal data) that must not reach logs.
        const err =
          exception instanceof Error
            ? {
                type: exception.name,
                message: exception.message,
                stack: exception.stack,
              }
            : { type: typeof exception };
        this.logger.error({ err, requestId, path: req.path }, 'Request failed');
      }
    }

    const body: ErrorEnvelope = {
      error: { code, message, details, requestId },
    };
    res.status(status).json(body);
  }

  private describe(exception: unknown): {
    status: number;
    code: ErrorCode;
    message: string;
    details: ErrorDetail[];
  } {
    if (exception instanceof AppException) {
      return {
        status: exception.getStatus(),
        code: exception.code,
        message: exception.message,
        details: exception.details,
      };
    }
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const code =
        STATUS_TO_CODE[status] ??
        (status >= 500 ? ErrorCode.INTERNAL_ERROR : ErrorCode.BAD_REQUEST);
      // Framework messages may echo internals (e.g. route paths); use safe defaults.
      return {
        status,
        code,
        message: DEFAULT_MESSAGES[code] ?? code,
        details: [],
      };
    }
    const bodyParserStatus = bodyParserErrorStatus(exception);
    if (bodyParserStatus !== undefined) {
      const code = STATUS_TO_CODE[bodyParserStatus] ?? ErrorCode.BAD_REQUEST;
      return {
        status: bodyParserStatus,
        code,
        message: DEFAULT_MESSAGES[code] ?? code,
        details: [],
      };
    }
    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      code: ErrorCode.INTERNAL_ERROR,
      message: DEFAULT_MESSAGES.INTERNAL_ERROR ?? 'Internal error',
      details: [],
    };
  }
}
