import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { AuditService } from '../audit/audit.service';

const INTERVAL_MS = 60 * 60 * 1000;
const FIRST_RUN_DELAY_MS = 30 * 1000;
const BATCH_SIZE = 500;

/**
 * Completes PLANNING events the day after their date, in each event's own
 * time zone (domain-model.md §4.6). Runs hourly in-process; the UPDATE is
 * idempotent, so overlapping runs or several instances are safe.
 */
@Injectable()
export class EventAutoCompleteJob
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(EventAutoCompleteJob.name);
  private timers: NodeJS.Timeout[] = [];

  constructor(
    private readonly dataSource: DataSource,
    private readonly audit: AuditService,
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

  /** Returns how many events were completed. */
  async run(now = new Date()): Promise<number> {
    let total = 0;
    for (;;) {
      const completed = await this.dataSource.transaction(async (manager) => {
        // TypeORM returns [rows, affectedCount] for UPDATE … RETURNING.
        const [rows] = await manager.query<
          [{ id: string; owner_user_id: string }[], number]
        >(
          `UPDATE events SET status = 'COMPLETED', status_changed_at = $1,
                    updated_at = $1, version = version + 1
             WHERE id IN (
               SELECT id FROM events
               WHERE status = 'PLANNING' AND deleted_at IS NULL
                 AND event_date < ($1::timestamptz AT TIME ZONE time_zone)::date
               ORDER BY event_date, id
               LIMIT ${BATCH_SIZE}
               FOR UPDATE SKIP LOCKED)
             RETURNING id, owner_user_id`,
          [now],
        );
        for (const row of rows) {
          await this.audit.record(manager, {
            actorType: 'SYSTEM',
            action: 'EVENT_AUTO_COMPLETED',
            entityType: 'EVENT',
            entityId: row.id,
            summary: {
              from: 'PLANNING',
              to: 'COMPLETED',
              ownerUserId: row.owner_user_id,
            },
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
      if (count > 0) this.logger.log(`Auto-completed ${count} past event(s)`);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Event auto-complete failed (${reason})`);
    }
  }
}
