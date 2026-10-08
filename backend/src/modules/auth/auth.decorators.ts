import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
/** Route needs no authentication (guest browsing, health). */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

export const OPTIONAL_AUTH_KEY = 'optionalAuth';
/**
 * Guests allowed, but a signed-in caller is identified (`@CurrentUser()` is
 * then set) so the route can show more (e.g. vendor contact details, A10).
 * A bad or expired token is still a 401, so the app refreshes it.
 */
export const OptionalAuth = () => SetMetadata(OPTIONAL_AUTH_KEY, true);

export const ALLOW_UNREGISTERED_KEY = 'allowUnregistered';
/** Valid Firebase identity required, but the platform user may not exist yet (`/auth/session`). */
export const AllowUnregistered = () =>
  SetMetadata(ALLOW_UNREGISTERED_KEY, true);

export const CHECK_REVOKED_KEY = 'checkRevoked';
/** Also checks Firebase token revocation (sensitive routes — identity-access.md §5). */
export const CheckRevoked = () => SetMetadata(CHECK_REVOKED_KEY, true);
