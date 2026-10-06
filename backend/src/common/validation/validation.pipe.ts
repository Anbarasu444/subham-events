import { HttpStatus, ValidationError, ValidationPipe } from '@nestjs/common';
import { AppException, ErrorDetail } from '../errors/app.exception';
import { ErrorCode } from '../errors/error-codes';

function flatten(errors: ValidationError[], parent?: string): ErrorDetail[] {
  return errors.flatMap((error) => {
    const field = parent ? `${parent}.${error.property}` : error.property;
    const own = Object.entries(error.constraints ?? {}).map(
      ([constraint, message]) => ({
        field,
        code: constraint.toUpperCase(),
        message,
      }),
    );
    return [...own, ...flatten(error.children ?? [], field)];
  });
}

/**
 * Global validation: whitelist + reject unknown properties, 422 with field details
 * (api-contracts.md §2, §4).
 */
export function createValidationPipe(): ValidationPipe {
  return new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    exceptionFactory: (errors) =>
      new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        flatten(errors),
      ),
  });
}
