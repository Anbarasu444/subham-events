import { stableStringify } from './idempotency.service';

describe('stableStringify', () => {
  it('is independent of key order and ignores undefined', () => {
    expect(stableStringify({ b: 1, a: { d: [1, 'x'], c: null } })).toBe(
      stableStringify({ a: { c: null, d: [1, 'x'] }, b: 1, e: undefined }),
    );
  });

  it('distinguishes different bodies', () => {
    expect(stableStringify({ a: '1' })).not.toBe(stableStringify({ a: 1 }));
    expect(stableStringify([1, 2])).not.toBe(stableStringify([2, 1]));
  });
});
