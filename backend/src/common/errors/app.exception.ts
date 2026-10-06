import { HttpException, HttpStatus } from '@nestjs/common';
import { DEFAULT_MESSAGES, ErrorCode } from './error-codes';

export interface ErrorDetail {
  field?: string;
  code: string;
  message: string;
}

/**
 * Domain/application error carrying a stable error code.
 * Services throw this; the global filter renders the error envelope.
 */
export class AppException extends HttpException {
  constructor(
    readonly code: ErrorCode,
    status: HttpStatus,
    message?: string,
    readonly details: ErrorDetail[] = [],
  ) {
    super(message ?? DEFAULT_MESSAGES[code] ?? code, status);
  }
}
