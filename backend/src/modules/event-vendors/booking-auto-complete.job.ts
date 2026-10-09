import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';

const INTERVAL_MS = 60 * 60 * 1000;
const FIRST_RUN_DELAY_MS = 45 * 1000;
const BATCH_SIZE = 500;

/**
 * Completes CONFIRMED bookings the day after their service date, in the
 * event's time zone (A7, domain-model.md §4.10), and sends N14 (in-app; the
 * review prompt arrives with M20). Hourly, idempotent, safe to overlap.
 */
@Injectable()
export class BookingAutoCompleteJob
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(BookingAutoCompleteJob.name);
  private timers: NodeJS.Timeout[] = [];

  constructor(
    private readonly dataSource: DataSource,
    private readonly audit: AuditService,
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

  /** Returns how many bookings were completed. */
  async run(now = new Date()): Promise<number> {
    let total = 0;
    for (;;) {
      const completed = await this.dataSource.transaction(async (manager) => {
        const [rows] = await manager.query<
          [
            {
              id: string;
              user_id: string;
              event_vendor_id: string;
              event_id: string;
            }[],
            number,
          ]
        >(
          `UPDATE bookings SET status = 'COMPLETED', completed_at = $1,
                  status_changed_at = $1, updated_at = $1, version = version + 1
            WHERE id IN (
              SELECT b.id FROM bookings b JOIN events e ON e.id = b.event_id
               WHERE b.status = 'CONFIRMED'
                 AND b.service_date < ($1::timestamptz AT TIME ZONE e.time_zone)::date
               ORDER BY b.service_date, b.id
               LIMIT ${BATCH_SIZE}
               FOR UPDATE OF b SKIP LOCKED)
            RETURNING id, user_id, event_vendor_id, event_id`,
          [now],
        );
        for (const row of rows) {
          await manager.query(
            `UPDATE event_vendors SET status = 'COMPLETED', status_changed_at = $2,
                    updated_at = $2, version = version + 1
              WHERE id = $1 AND status = 'BOOKED'`,
            [row.event_vendor_id, now],
          );
          await this.notifications.createInApp(manager, {
            recipientUserId: row.user_id,
            audience: 'USER',
            category: 'BOOKING',
            type: 'BOOKING_COMPLETED',
            title: 'Booking completed',
            body: 'Your booking is complete. How did it go? Rate the vendor.',
            entityType: 'BOOKING',
            entityId: row.id,
            data: { eventId: row.event_id, eventVendorId: row.event_vendor_id },
          });
          await this.audit.record(manager, {
            actorType: 'SYSTEM',
            action: 'BOOKING_AUTO_COMPLETED',
            entityType: 'BOOKING',
            entityId: row.id,
            summary: { eventId: row.event_id },
          });
        }
        return rows.length;
      });
      total += completed;
      if (completed < BATCH_SIZE) return total;
    }
  }

  private async runSafely(): Promise<void> {
    try {
      const count = await this.run();
      if (count > 0) this.logger.log(`Auto-completed ${count} booking(s)`);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Booking auto-complete failed (${reason})`);
    }
  }
}
