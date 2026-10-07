/**
 * Stable machine-readable error codes (api-contracts.md Part A §4).
 * Never reuse a code with a different meaning.
 */
export const ErrorCode = {
  BAD_REQUEST: 'BAD_REQUEST',
  AUTH_REQUIRED: 'AUTH_REQUIRED',
  AUTH_TOKEN_EXPIRED: 'AUTH_TOKEN_EXPIRED',
  AUTH_TOKEN_INVALID: 'AUTH_TOKEN_INVALID',
  AUTH_TOKEN_REVOKED: 'AUTH_TOKEN_REVOKED',
  ADMIN_LOGIN_FAILED: 'ADMIN_LOGIN_FAILED',
  ADMIN_SESSION_EXPIRED: 'ADMIN_SESSION_EXPIRED',
  ACCOUNT_SUSPENDED: 'ACCOUNT_SUSPENDED',
  ACCOUNT_DELETED: 'ACCOUNT_DELETED',
  FORBIDDEN_ROLE: 'FORBIDDEN_ROLE',
  FORBIDDEN_PERMISSION: 'FORBIDDEN_PERMISSION',
  ADMIN_PASSWORD_CHANGE_REQUIRED: 'ADMIN_PASSWORD_CHANGE_REQUIRED',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  INVALID_STATE_TRANSITION: 'INVALID_STATE_TRANSITION',
  IDEMPOTENCY_KEY_REUSED: 'IDEMPOTENCY_KEY_REUSED',
  DUPLICATE: 'DUPLICATE',
  PRECONDITION_FAILED: 'PRECONDITION_FAILED',
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  MEDIA_INVALID: 'MEDIA_INVALID',
  ADMIN_ACCOUNT_LOCKED: 'ADMIN_ACCOUNT_LOCKED',
  CLIENT_UPGRADE_REQUIRED: 'CLIENT_UPGRADE_REQUIRED',
  IDEMPOTENCY_KEY_REQUIRED: 'IDEMPOTENCY_KEY_REQUIRED',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  PAYMENT_PROVIDER_ERROR: 'PAYMENT_PROVIDER_ERROR',
  AUTH_PROVIDER_UNAVAILABLE: 'AUTH_PROVIDER_UNAVAILABLE',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
} as const;

export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

/** Safe, generic default messages; clients localise by code. */
export const DEFAULT_MESSAGES: Partial<Record<ErrorCode, string>> = {
  BAD_REQUEST: 'The request could not be understood.',
  AUTH_REQUIRED: 'Please sign in to continue.',
  AUTH_TOKEN_EXPIRED: 'Your session has expired.',
  AUTH_TOKEN_INVALID: 'Your session is not valid. Please sign in again.',
  AUTH_TOKEN_REVOKED: 'You have been signed out. Please sign in again.',
  ACCOUNT_SUSPENDED: 'This account is suspended.',
  ACCOUNT_DELETED: 'This account has been deleted.',
  FORBIDDEN_ROLE: 'You do not have access to this.',
  FORBIDDEN_PERMISSION: 'You do not have permission to do this.',
  AUTH_PROVIDER_UNAVAILABLE:
    'Sign-in is temporarily unavailable. Please try again.',
  NOT_FOUND: 'The requested resource was not found.',
  CONFLICT: 'The request conflicts with the current state.',
  PAYLOAD_TOO_LARGE: 'The request is too large.',
  VALIDATION_FAILED: 'Some fields are invalid.',
  RATE_LIMITED: 'Too many requests. Please try again later.',
  INTERNAL_ERROR: 'Something went wrong. Please try again.',
  SERVICE_UNAVAILABLE: 'The service is temporarily unavailable.',
};
