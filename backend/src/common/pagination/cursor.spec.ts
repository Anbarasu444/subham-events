import { AppException } from '../errors/app.exception';
import { decodeCursor, encodeCursor, toCursorPage } from './cursor';

describe('cursor pagination', () => {
  it('round-trips a cursor', () => {
    const cursor = encodeCursor({ d: '2026-12-14', i: 'abc' });
    expect(decodeCursor(cursor, ['d', 'i'] as const)).toEqual({
      d: '2026-12-14',
      i: 'abc',
    });
  });

  it('rejects garbage, missing keys and invalid values with 422', () => {
    const bad = [
      'not-base64-json',
      encodeCursor({ d: '2026-12-14' }),
      encodeCursor({ d: 'x', i: 'abc' }),
    ];
    for (const cursor of bad) {
      expect(() =>
        decodeCursor(cursor, ['d', 'i'] as const, {
          d: (v) => /^\d{4}-\d{2}-\d{2}$/.test(v),
        }),
      ).toThrow(AppException);
    }
  });

  it('splits limit + 1 rows into a page with the next cursor', () => {
    const rows = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    const { items, page } = toCursorPage(rows, 2, (r) => ({ i: r.id }));
    expect(items).toEqual([{ id: 'a' }, { id: 'b' }]);
    expect(page.hasMore).toBe(true);
    expect(decodeCursor(page.nextCursor!, ['i'] as const)).toEqual({ i: 'b' });

    const last = toCursorPage(rows.slice(0, 2), 2, (r) => ({ i: r.id }));
    expect(last.page).toEqual({
      type: 'cursor',
      limit: 2,
      nextCursor: null,
      hasMore: false,
    });
  });
});
