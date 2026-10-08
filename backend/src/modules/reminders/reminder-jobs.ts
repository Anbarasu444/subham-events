import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { NotificationsService } from '../notifications/notifications.service';

const BATCH_SIZE = 500;
const REMINDER_INTERVAL_MS = 60 * 1000;
const CHECKLIST_INTERVAL_MS = 15 * 60 * 1000;
/** Checklist alerts go out from this local hour (M17 answer 2). */
const ALERT_HOUR = 9;

/**
 * M17 background work, in-process and idempotent (safe to overlap or run on
 * several instances): fires due reminders (N17) every minute, and sends the
 * checklist "due today" / "overdue" alerts (N16) once per task per state
 * from 09:00 in each event's time zone. In-app records now; pushes in M18.
 */
@Injectable()
export class ReminderJobs
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(ReminderJobs.name);
  private timers: NodeJS.Timeout[] = [];

  constructor(
    private readonly dataSource: DataSource,
    private readonly notifications: NotificationsService,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.config.backgroundJobsEnabled) return;
    const every = (ms: number, run: () => Promise<number>, what: string) => {
      const timer = setInterval(() => void this.safely(run, what), ms);
      timer.unref();
      this.timers.push(timer);
    };
    every(REMINDER_INTERVAL_MS, () => this.fireDueReminders(), 'reminders');
    every(
      CHECKLIST_INTERVAL_MS,
      () => this.sendChecklistAlerts(),
      'checklist alerts',
    );
  }

  onApplicationShutdown(): void {
    for (const timer of this.timers) clearInterval(timer);
  }

  /** SCHEDULED reminders whose time has come → SENT + N17. */
  async fireDueReminders(now = new Date()): Promise<number> {
    let total = 0;
    for (;;) {
      const sent = await this.dataSource.transaction(async (manager) => {
        const [rows] = await manager.query<
          [
            {
              id: string;
              user_id: string;
              event_id: string;
              title: string;
              checklist_item_id: string | null;
            }[],
            number,
          ]
        >(
          `UPDATE reminders SET status = 'SENT', sent_at = $1, updated_at = $1,
                  version = version + 1
            WHERE id IN (
              SELECT r.id FROM reminders r JOIN events e ON e.id = r.event_id
               WHERE r.status = 'SCHEDULED' AND r.remind_at <= $1
                 AND e.deleted_at IS NULL
               ORDER BY r.remind_at, r.id
               LIMIT ${BATCH_SIZE}
               FOR UPDATE OF r SKIP LOCKED)
            RETURNING id, user_id, event_id, title, checklist_item_id`,
          [now],
        );
        for (const r of rows) {
          await this.notifications.createInApp(manager, {
            recipientUserId: r.user_id,
            audience: 'USER',
            category: 'CHECKLIST',
            type: 'REMINDER_DUE',
            title: 'Reminder',
            body: r.title,
            entityType: 'REMINDER',
            entityId: r.id,
            data: { eventId: r.event_id, checklistItemId: r.checklist_item_id },
          });
        }
        return rows.length;
      });
      total += sent;
      if (sent < BATCH_SIZE) return total;
    }
  }

  /**
   * N16 once per task per state: DUE_TODAY on the due date, OVERDUE from the
   * next day — both only from 09:00 local time, for PENDING tasks of PLANNING
   * events.
   */
  async sendChecklistAlerts(now = new Date()): Promise<number> {
    return this.dataSource.transaction(async (manager) => {
      const rows = await manager.query<
        {
          checklist_item_id: string;
          kind: 'DUE_TODAY' | 'OVERDUE';
          owner_user_id: string;
          event_id: string;
          title: string;
        }[]
      >(
        `WITH candidates AS (
           SELECT ci.id, ci.title, e.id AS event_id, e.owner_user_id,
                  CASE WHEN ci.due_date = local.today THEN 'DUE_TODAY' ELSE 'OVERDUE' END AS kind
             FROM checklist_items ci
             JOIN events e ON e.id = ci.event_id
             CROSS JOIN LATERAL (
               SELECT ($1::timestamptz AT TIME ZONE e.time_zone)::date AS today,
                      extract(hour FROM ($1::timestamptz AT TIME ZONE e.time_zone)) AS hour
             ) local
            WHERE ci.status = 'PENDING' AND ci.deleted_at IS NULL AND ci.due_date IS NOT NULL
              AND e.status = 'PLANNING' AND e.deleted_at IS NULL
              AND local.hour >= ${ALERT_HOUR}
              AND ci.due_date <= local.today
         ),
         inserted AS (
           INSERT INTO checklist_alerts (checklist_item_id, kind)
           SELECT id, kind FROM candidates
           ON CONFLICT DO NOTHING
           RETURNING checklist_item_id, kind
         )
         SELECT i.checklist_item_id, i.kind, c.owner_user_id, c.event_id, c.title
           FROM inserted i JOIN candidates c ON c.id = i.checklist_item_id`,
        [now],
      );
      for (const r of rows) {
        await this.notifications.createInApp(manager, {
          recipientUserId: r.owner_user_id,
          audience: 'USER',
          category: 'CHECKLIST',
          type:
            r.kind === 'DUE_TODAY'
              ? 'CHECKLIST_DUE_TODAY'
              : 'CHECKLIST_OVERDUE',
          title: r.kind === 'DUE_TODAY' ? 'Task due today' : 'Task overdue',
          body: r.title,
          entityType: 'CHECKLIST_ITEM',
          entityId: r.checklist_item_id,
          data: { eventId: r.event_id },
        });
      }
      return rows.length;
    });
  }

  private async safely(
    run: () => Promise<number>,
    what: string,
  ): Promise<void> {
    try {
      const count = await run();
      if (count > 0) this.logger.log(`Sent ${count} ${what}`);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Sending ${what} failed (${reason})`);
    }
  }
}
