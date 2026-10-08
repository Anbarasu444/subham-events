import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppConfigService } from '../../config/app-config.service';
import { FcmSender } from './fcm-sender';
import type { NotificationCategory } from './notification.entity';
import { androidChannelOf, pushGroupOf } from './push-policy';

const INTERVAL_MS = 10 * 1000;
const BATCH_SIZE = 50;
const MAX_ATTEMPTS = 5;
/** A claimed row is retried by another run if this worker dies. */
const LEASE_MINUTES = 2;

interface PendingRow {
  id: string;
  recipient_user_id: string;
  audience: 'USER' | 'VENDOR';
  category: NotificationCategory;
  type: string;
  entity_type: string | null;
  entity_id: string | null;
  title: string;
  body: string;
  deep_link: string | null;
  data: Record<string, unknown>;
  push_attempts: number;
}

/**
 * Delivers queued pushes (M18, notification-matrix.md Part A §1): leases
 * PENDING rows, skips them when the group is switched off or the user has no
 * active device, sends per device, deactivates invalid tokens, and retries
 * transient failures with backoff (2, 4, 8, 16 minutes; FAILED after 5).
 * At-least-once: the app de-duplicates by notificationId.
 */
@Injectable()
export class PushWorker
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(PushWorker.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly dataSource: DataSource,
    private readonly fcm: FcmSender,
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

  /** One pass; returns how many notifications were processed. */
  async run(now = new Date()): Promise<number> {
    const [rows] = await this.dataSource.query<[PendingRow[], number]>(
      `UPDATE notifications
          SET push_next_at = $1::timestamptz + interval '${LEASE_MINUTES} minutes',
              push_attempts = push_attempts + 1
        WHERE id IN (
          SELECT id FROM notifications
           WHERE delivery_status = 'PENDING' AND push_next_at <= $1
           ORDER BY push_next_at, id
           LIMIT ${BATCH_SIZE}
           FOR UPDATE SKIP LOCKED)
        RETURNING id, recipient_user_id, audience, category, type, entity_type,
                  entity_id, title, body, deep_link, data, push_attempts`,
      [now],
    );
    for (const row of rows) await this.deliver(row, now);
    return rows.length;
  }

  private async deliver(row: PendingRow, now: Date): Promise<void> {
    const group = pushGroupOf(row.category);
    const [pref] = await this.dataSource.query<{ push_enabled: boolean }[]>(
      `SELECT push_enabled FROM notification_preferences
        WHERE user_id = $1 AND push_group = $2`,
      [row.recipient_user_id, group],
    );
    if (pref && !pref.push_enabled) {
      return this.finish(row.id, 'SKIPPED', 'push turned off');
    }
    const devices = await this.dataSource.query<{ fcm_token: string }[]>(
      `SELECT fcm_token FROM notification_devices
        WHERE user_id = $1 AND audience = $2 AND is_active`,
      [row.recipient_user_id, row.audience],
    );
    if (devices.length === 0) {
      return this.finish(row.id, 'SKIPPED', 'no active device');
    }
    const tokens = devices.map((d) => d.fcm_token);
    const results = await this.fcm.send(tokens, {
      title: row.title,
      body: row.body,
      // Ids and routing only: never personal data in the payload.
      data: {
        notificationId: row.id,
        type: row.type,
        ...(row.entity_type ? { entityType: row.entity_type } : {}),
        ...(row.entity_id ? { entityId: row.entity_id } : {}),
        ...(row.deep_link ? { deepLink: row.deep_link } : {}),
        ...(typeof row.data.eventId === 'string'
          ? { eventId: row.data.eventId }
          : {}),
      },
      androidChannelId: androidChannelOf(group),
      threadId: androidChannelOf(group),
    });
    const invalid = tokens.filter((_, i) => results[i] === 'INVALID_TOKEN');
    if (invalid.length) {
      await this.dataSource.query(
        `UPDATE notification_devices SET is_active = false, updated_at = now()
          WHERE fcm_token = ANY($1::text[])`,
        [invalid],
      );
    }
    if (results.includes('SENT')) {
      await this.dataSource.query(
        `UPDATE notifications SET delivery_status = 'SENT', pushed_at = $2,
                push_next_at = NULL, push_error = NULL
          WHERE id = $1`,
        [row.id, now],
      );
      return;
    }
    if (!results.includes('RETRY')) {
      return this.finish(row.id, 'SKIPPED', 'no valid device');
    }
    if (row.push_attempts >= MAX_ATTEMPTS) {
      return this.finish(row.id, 'FAILED', 'gave up after retries');
    }
    const backoffMinutes = 2 ** row.push_attempts;
    await this.dataSource.query(
      `UPDATE notifications
          SET push_next_at = $2::timestamptz + make_interval(mins => $3),
              push_error = 'transient send failure'
        WHERE id = $1`,
      [row.id, now, backoffMinutes],
    );
  }

  private async finish(
    id: string,
    status: 'SKIPPED' | 'FAILED',
    reason: string,
  ): Promise<void> {
    await this.dataSource.query(
      `UPDATE notifications SET delivery_status = $2, push_next_at = NULL,
              push_error = $3
        WHERE id = $1`,
      [id, status, reason],
    );
  }

  private async runSafely(): Promise<void> {
    try {
      await this.run();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Push delivery pass failed (${reason})`);
    }
  }
}
