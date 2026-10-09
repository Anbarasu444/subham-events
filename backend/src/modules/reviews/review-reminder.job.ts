import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { NotificationsService } from '../notifications/notifications.service';

const INTERVAL_MS = 60 * 60 * 1000;
const FIRST_RUN_DELAY_MS = 60 * 1000;
const BATCH_SIZE = 500;

/**
 * One "rate the vendor" reminder per completed booking, 3 days after it was
 * completed, if it has no review yet (M20 change, user 2026-10-09). Bookings
 * completed more than 30 days ago are not reminded (no backlog burst).
 * Hourly, idempotent (`review_reminded_at`), safe to overlap.
 */
@Injectable()
export class ReviewReminderJob
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(ReviewReminderJob.name);
  private timers: NodeJS.Timeout[] = [];

  constructor(
    private readonly dataSource: DataSource,
    private readonly notifications: NotificationsService,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.config.backgroundJobsEnabled) return;
    const first = setTimeout(() => void this.runSafely(), FIRST_RUN_DELAY_MS);
    const repeat = setInterval(() => void this.runSafely(), INTERVAL_MS);
    first.unref();
    repeat.unref();
    this.timers = [first, repeat];
  }

  onApplicationShutdown(): void {
    for (const timer of this.timers) clearTimeout(timer);
  }

  /** Returns how many reminders were created. */
  async run(now = new Date()): Promise<number> {
    let total = 0;
    for (;;) {
      const sent = await this.dataSource.transaction(async (manager) => {
        const [rows] = await manager.query<
          [
            {
              id: string;
              user_id: string;
              event_id: string;
              event_vendor_id: string;
            }[],
            number,
          ]
        >(
          `UPDATE bookings SET review_reminded_at = $1
            WHERE id IN (
              SELECT b.id FROM bookings b JOIN events e ON e.id = b.event_id
               WHERE b.status = 'COMPLETED' AND b.review_reminded_at IS NULL
                 AND b.completed_at <= $1::timestamptz - interval '3 days'
                 AND b.completed_at > $1::timestamptz - interval '30 days'
                 AND e.deleted_at IS NULL
                 AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.booking_id = b.id)
               ORDER BY b.completed_at, b.id
               LIMIT ${BATCH_SIZE}
               FOR UPDATE OF b SKIP LOCKED)
            RETURNING id, user_id, event_id, event_vendor_id`,
          [now],
        );
        if (rows.length === 0) return 0;
        const titles = new Map(
          (
            await manager.query<{ id: string; title: string }[]>(
              `SELECT ev.id, l.title FROM event_vendors ev
                 JOIN vendor_listings l ON l.id = ev.listing_id
                WHERE ev.id = ANY($1::uuid[])`,
              [rows.map((r) => r.event_vendor_id)],
            )
          ).map((t) => [t.id, t.title]),
        );
        for (const row of rows) {
          const title = titles.get(row.event_vendor_id) ?? 'your vendor';
          await this.notifications.createInApp(manager, {
            recipientUserId: row.user_id,
            audience: 'USER',
            category: 'REVIEW',
            type: 'REVIEW_REMINDER',
            title: 'How did it go?',
            body: `Rate “${title}” to help others choose.`,
            entityType: 'BOOKING',
            entityId: row.id,
            data: { eventId: row.event_id, eventVendorId: row.event_vendor_id },
          });
        }
        return rows.length;
      });
      total += sent;
      if (sent < BATCH_SIZE) return total;
    }
  }

  private async runSafely(): Promise<void> {
    try {
      await this.run();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Review reminders failed (${reason})`);
    }
  }
}
