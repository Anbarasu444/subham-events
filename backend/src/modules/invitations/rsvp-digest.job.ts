import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { NotificationsService } from '../notifications/notifications.service';

const INTERVAL_MS = 5 * 60 * 1000;

/**
 * N18 digest (domain-model.md §4.15): at most one "new RSVPs" notification
 * per invitation per hour, counting replies since the last one.
 */
@Injectable()
export class RsvpDigestJob
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(RsvpDigestJob.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly dataSource: DataSource,
    private readonly notifications: NotificationsService,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.config.backgroundJobsEnabled) return;
    this.timer = setInterval(() => void this.runSafely(), INTERVAL_MS);
    this.timer.unref();
  }

  onApplicationShutdown(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async run(now = new Date()): Promise<number> {
    return this.dataSource.transaction(async (manager) => {
      // Lock the invitations first (FOR UPDATE cannot be combined with
      // GROUP BY), then count each one's new replies.
      const rows = await manager.query<
        {
          id: string;
          user_id: string;
          event_id: string;
          title: string;
          replies: number;
        }[]
      >(
        `WITH due AS (
           SELECT i.id, i.user_id, i.event_id, i.title, i.last_rsvp_notified_at
             FROM invitations i
            WHERE (i.last_rsvp_notified_at IS NULL
                   OR i.last_rsvp_notified_at <= $1::timestamptz - interval '1 hour')
              AND EXISTS (
                SELECT 1 FROM invitation_rsvps r
                 WHERE r.invitation_id = i.id
                   AND r.updated_at > COALESCE(i.last_rsvp_notified_at, '-infinity'::timestamptz))
            ORDER BY i.id
            FOR UPDATE OF i SKIP LOCKED
         )
         SELECT d.id, d.user_id, d.event_id, d.title,
                (SELECT count(*)::int FROM invitation_rsvps r
                  WHERE r.invitation_id = d.id
                    AND r.updated_at > COALESCE(d.last_rsvp_notified_at, '-infinity'::timestamptz)) AS replies
           FROM due d`,
        [now],
      );
      for (const row of rows) {
        await manager.query(
          `UPDATE invitations SET last_rsvp_notified_at = $2 WHERE id = $1`,
          [row.id, now],
        );
        await this.notifications.createInApp(manager, {
          recipientUserId: row.user_id,
          audience: 'USER',
          category: 'INVITATION',
          type: 'RSVP_RECEIVED',
          title: row.replies === 1 ? 'New RSVP' : `${row.replies} new RSVPs`,
          body: `Replies to “${row.title}”.`,
          entityType: 'INVITATION',
          entityId: row.id,
          data: { eventId: row.event_id, count: row.replies },
        });
      }
      return rows.length;
    });
  }

  private async runSafely(): Promise<void> {
    try {
      await this.run();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`RSVP digest failed (${reason})`);
    }
  }
}
