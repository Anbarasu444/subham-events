import {
  isCalendarDate,
  isValidTimeZone,
  localDate,
  nextStatus,
} from './event-rules';

describe('event rules', () => {
  // 2026-10-07 20:00 UTC = 2026-10-08 01:30 in India.
  const now = new Date('2026-10-07T20:00:00.000Z');

  it('computes the local date in the event time zone', () => {
    expect(localDate('Asia/Kolkata', now)).toBe('2026-10-08');
    expect(localDate('UTC', now)).toBe('2026-10-07');
  });

  it('validates time zones and calendar dates', () => {
    expect(isValidTimeZone('Asia/Kolkata')).toBe(true);
    expect(isValidTimeZone('Mars/Base')).toBe(false);
    expect(isValidTimeZone('America/Argentina/Buenos_Aires')).toBe(true);
    expect(isValidTimeZone('UTC')).toBe(true);
    for (const bad of [
      '+05:30',
      'EST5EDT',
      'Etc/GMT+5',
      'asia/kolkata',
      'Asia/Nowhere',
    ]) {
      expect(isValidTimeZone(bad)).toBe(false);
    }
    expect(isCalendarDate('2026-02-28')).toBe(true);
    expect(isCalendarDate('2026-02-30')).toBe(false);
    expect(isCalendarDate('26-02-01')).toBe(false);
    expect(isCalendarDate('1999-12-31')).toBe(false);
  });

  const event = (
    status: 'PLANNING' | 'COMPLETED' | 'CANCELLED',
    eventDate: string,
  ) => ({
    status,
    eventDate,
    timeZone: 'Asia/Kolkata',
  });

  it('allows cancel and complete only while planning', () => {
    expect(nextStatus('cancel', event('PLANNING', '2026-12-01'), now)).toBe(
      'CANCELLED',
    );
    expect(nextStatus('complete', event('PLANNING', '2026-12-01'), now)).toBe(
      'COMPLETED',
    );
    expect(
      nextStatus('cancel', event('CANCELLED', '2026-12-01'), now),
    ).toBeNull();
    expect(
      nextStatus('complete', event('COMPLETED', '2026-12-01'), now),
    ).toBeNull();
  });

  it('reopens only while the date is today or later in the event zone', () => {
    expect(nextStatus('reopen', event('CANCELLED', '2026-10-08'), now)).toBe(
      'PLANNING',
    );
    expect(
      nextStatus('reopen', event('COMPLETED', '2026-10-07'), now),
    ).toBeNull();
    expect(
      nextStatus('reopen', event('PLANNING', '2026-12-01'), now),
    ).toBeNull();
  });
});
