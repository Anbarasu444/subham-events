import type { EventStatus } from './event.entity';

export const DEFAULT_EVENT_TIME_ZONE = 'Asia/Kolkata';

export type EventAction = 'cancel' | 'reopen' | 'complete';

/** Today's calendar date (`YYYY-MM-DD`) in an IANA time zone. */
export function localDate(timeZone: string, now: Date): string {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/**
 * Region/City IANA names (or UTC) only. Offsets (`+05:30`), POSIX rules
 * (`EST5EDT`) and `Etc/*` are rejected: PostgreSQL interprets some of them
 * differently (sign-reversed offsets), which would shift "today".
 */
const ZONE_SHAPE =
  /^(UTC|(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)\/[A-Za-z0-9_+-]+(\/[A-Za-z0-9_+-]+)?)$/;

export function isValidTimeZone(timeZone: string): boolean {
  if (!ZONE_SHAPE.test(timeZone)) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return true;
  } catch {
    return false;
  }
}

/** Real calendar date in `YYYY-MM-DD` between 2000 and 2100. */
export function isCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const [year, month, day] = match.slice(1).map(Number);
  if (year < 2000 || year > 2100) return false;
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

/**
 * Event state machine (domain-model.md §4.6):
 * PLANNING → COMPLETED | CANCELLED; COMPLETED | CANCELLED → PLANNING while
 * the event date is today or later (in the event's time zone).
 */
export function nextStatus(
  action: EventAction,
  current: { status: EventStatus; eventDate: string; timeZone: string },
  now: Date,
): EventStatus | null {
  switch (action) {
    case 'cancel':
      return current.status === 'PLANNING' ? 'CANCELLED' : null;
    case 'complete':
      return current.status === 'PLANNING' ? 'COMPLETED' : null;
    case 'reopen':
      return current.status !== 'PLANNING' &&
        current.eventDate >= localDate(current.timeZone, now)
        ? 'PLANNING'
        : null;
  }
}
