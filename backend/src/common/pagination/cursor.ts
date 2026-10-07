import { HttpStatus } from '@nestjs/common';
import { AppException } from '../errors/app.exception';
import { ErrorCode } from '../errors/error-codes';

/** `meta.page` for cursor-paginated lists (api-contracts.md §5, ADR-0013). */
export interface CursorPageMeta {
  type: 'cursor';
  limit: number;
  nextCursor: string | null;
  hasMore: boolean;
}

export const DEFAULT_PAGE_LIMIT = 20;
export const MAX_PAGE_LIMIT = 100;

/** Opaque cursor: base64url JSON of the sort key and id. */
export function encodeCursor(value: Record<string, string>): string {
  return Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
}

/**
 * Decodes a cursor and checks that it carries the expected string keys and,
 * when given, that each value passes [isValid] (so a tampered cursor is a
 * 422, never a database error).
 */
export function decodeCursor<K extends string>(
  cursor: string,
  keys: readonly K[],
  isValid: Partial<Record<K, (value: string) => boolean>> = {},
): Record<K, string> {
  try {
    const parsed: unknown = JSON.parse(
      Buffer.from(cursor, 'base64url').toString('utf8'),
    );
    if (
      parsed &&
      typeof parsed === 'object' &&
      keys.every((k) => {
        const value = (parsed as Record<string, unknown>)[k];
        return typeof value === 'string' && (isValid[k]?.(value) ?? true);
      })
    ) {
      return parsed as Record<K, string>;
    }
  } catch {
    // fall through
  }
  throw new AppException(
    ErrorCode.VALIDATION_FAILED,
    HttpStatus.UNPROCESSABLE_ENTITY,
    undefined,
    [{ field: 'cursor', code: 'INVALID_CURSOR', message: 'cursor is invalid' }],
  );
}

/** Splits a `limit + 1` result into the page and its metadata. */
export function toCursorPage<T>(
  rows: T[],
  limit: number,
  cursorOf: (last: T) => Record<string, string>,
): { items: T[]; page: CursorPageMeta } {
  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;
  const last = items.at(-1);
  return {
    items,
    page: {
      type: 'cursor',
      limit,
      nextCursor: hasMore && last ? encodeCursor(cursorOf(last)) : null,
      hasMore,
    },
  };
}
