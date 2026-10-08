import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

export const NOTIFICATION_CATEGORIES = [
  'AUTH',
  'CATEGORY',
  'VENDOR',
  'EVENT',
  'BOOKING',
  'PAYMENT',
  'CHECKLIST',
  'INVITATION',
  'REVIEW',
  'SYSTEM',
] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];
export type NotificationAudience = 'USER' | 'VENDOR' | 'ADMIN';
export type PushPolicy = 'ALWAYS' | 'IF_ENABLED' | 'NEVER';

/** In-app notification record — the source of truth (notification-matrix.md Part A). */
@Entity('notifications')
export class NotificationEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'recipient_type', type: 'text' })
  recipientType: 'USER' | 'ADMIN';

  @Column({ name: 'recipient_user_id', type: 'uuid', nullable: true })
  recipientUserId: string | null;

  @Column({ name: 'recipient_admin_id', type: 'uuid', nullable: true })
  recipientAdminId: string | null;

  @Column({ type: 'text' })
  audience: NotificationAudience;

  @Column({ type: 'text' })
  category: NotificationCategory;

  @Column({ type: 'text' })
  type: string;

  @Column({ name: 'entity_type', type: 'text', nullable: true })
  entityType: string | null;

  @Column({ name: 'entity_id', type: 'uuid', nullable: true })
  entityId: string | null;

  @Column({ type: 'text' })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ name: 'deep_link', type: 'text', nullable: true })
  deepLink: string | null;

  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  data: Record<string, unknown>;

  @Column({ name: 'push_policy', type: 'text' })
  pushPolicy: PushPolicy;

  @Column({ name: 'delivery_status', type: 'text', default: 'NOT_REQUIRED' })
  deliveryStatus: 'NOT_REQUIRED' | 'PENDING' | 'SENT' | 'SKIPPED' | 'FAILED';

  @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
  readAt: Date | null;

  /** Push outbox (M18): attempts so far, next attempt (lease), last error. */
  @Column({ name: 'push_attempts', type: 'integer', default: 0 })
  pushAttempts: number;

  @Column({ name: 'push_next_at', type: 'timestamptz', nullable: true })
  pushNextAt: Date | null;

  @Column({ name: 'push_error', type: 'text', nullable: true })
  pushError: string | null;

  @Column({ name: 'pushed_at', type: 'timestamptz', nullable: true })
  pushedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
