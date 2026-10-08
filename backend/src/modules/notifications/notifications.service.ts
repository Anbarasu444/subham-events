import { Injectable } from '@nestjs/common';
import type { EntityManager } from 'typeorm';
import { uuidv7 } from '../../common/ids/uuid-v7';
import {
  NotificationAudience,
  NotificationCategory,
  NotificationEntity,
} from './notification.entity';
import { USER_PUSH_TYPES } from './push-policy';

export interface InAppNotification {
  recipientUserId: string;
  audience: NotificationAudience;
  category: NotificationCategory;
  type: string;
  title: string;
  body: string;
  entityType?: string;
  entityId?: string;
  deepLink?: string;
  /** Structured fields for the client (no secrets, minimal personal data). */
  data?: Record<string, unknown>;
}

@Injectable()
export class NotificationsService {
  /**
   * Creates an in-app notification in the caller's transaction; push-worthy
   * user types are also queued for push (M18, PushWorker).
   */
  async createInApp(
    manager: EntityManager,
    n: InAppNotification,
  ): Promise<string> {
    const id = uuidv7();
    const pushed = n.audience === 'USER' && USER_PUSH_TYPES.has(n.type);
    await manager.insert(NotificationEntity, {
      id,
      recipientType: 'USER',
      recipientUserId: n.recipientUserId,
      recipientAdminId: null,
      audience: n.audience,
      category: n.category,
      type: n.type,
      entityType: n.entityType ?? null,
      entityId: n.entityId ?? null,
      title: n.title,
      body: n.body,
      deepLink: n.deepLink ?? null,
      data: (n.data ?? {}) as NotificationEntity['data'] & object,
      // M18: user-facing types are pushed (if the user allows the group);
      // the row itself is the push outbox, written in the same transaction.
      ...(pushed
        ? {
            pushPolicy: 'IF_ENABLED' as const,
            deliveryStatus: 'PENDING' as const,
            pushNextAt: new Date(),
          }
        : {
            pushPolicy: 'NEVER' as const,
            deliveryStatus: 'NOT_REQUIRED' as const,
          }),
    });
    return id;
  }
}
