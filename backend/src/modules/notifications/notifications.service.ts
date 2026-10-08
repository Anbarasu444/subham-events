import { Injectable } from '@nestjs/common';
import type { EntityManager } from 'typeorm';
import { uuidv7 } from '../../common/ids/uuid-v7';
import {
  NotificationAudience,
  NotificationCategory,
  NotificationEntity,
} from './notification.entity';

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
   * Creates an in-app-only notification in the caller's transaction.
   * Push delivery (outbox + FCM) arrives with M18.
   */
  async createInApp(
    manager: EntityManager,
    n: InAppNotification,
  ): Promise<string> {
    const id = uuidv7();
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
      pushPolicy: 'NEVER',
      deliveryStatus: 'NOT_REQUIRED',
    });
    return id;
  }
}
