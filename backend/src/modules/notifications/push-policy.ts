import type { NotificationCategory } from './notification.entity';

/** Push preference groups (M18 answer 5). */
export const PUSH_GROUPS = ['BOOKINGS', 'REMINDERS', 'OTHER'] as const;
export type PushGroup = (typeof PUSH_GROUPS)[number];

/**
 * User-facing types that are pushed (M18 answer 3; notification-matrix.md):
 * quotes, bookings, reminders and checklist alerts. Everything else stays
 * in-app only. Vendor pushes start with the Vendor App (M36).
 */
export const USER_PUSH_TYPES: ReadonlySet<string> = new Set([
  'QUOTATION_RECEIVED',
  'BOOKING_CONFIRMED',
  'BOOKING_CANCELLED',
  'BOOKING_COMPLETED',
  'REMINDER_DUE',
  'CHECKLIST_DUE_TODAY',
  'CHECKLIST_OVERDUE',
  // M19: the hourly RSVP digest (OTHER group).
  'RSVP_RECEIVED',
  // M20: one "rate the vendor" reminder 3 days after completion (OTHER).
  'REVIEW_REMINDER',
]);

export function pushGroupOf(category: NotificationCategory): PushGroup {
  switch (category) {
    case 'BOOKING':
    case 'PAYMENT':
      return 'BOOKINGS';
    case 'CHECKLIST':
      return 'REMINDERS';
    default:
      return 'OTHER';
  }
}

/** Android notification channel per group (matrix §3). */
export function androidChannelOf(group: PushGroup): string {
  switch (group) {
    case 'BOOKINGS':
      return 'bookings';
    case 'REMINDERS':
      return 'reminders';
    default:
      return 'general';
  }
}
