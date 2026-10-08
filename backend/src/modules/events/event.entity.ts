import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export const EVENT_STATUSES = ['PLANNING', 'COMPLETED', 'CANCELLED'] as const;
export type EventStatus = (typeof EVENT_STATUSES)[number];

/** The user's planned event — central planning entity (domain-model.md §4.6). */
@Entity('events')
export class EventEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'owner_user_id', type: 'uuid' })
  ownerUserId: string;

  /** Free text chosen by the user (O1). */
  @Column({ name: 'event_type', type: 'text' })
  eventType: string;

  @Column({ type: 'text' })
  title: string;

  /** Calendar date `YYYY-MM-DD` in the event's time zone. */
  @Column({ name: 'event_date', type: 'date' })
  eventDate: string;

  /** `HH:MM:SS` from PostgreSQL; the API exposes `HH:mm`. */
  @Column({ name: 'start_time', type: 'time', nullable: true })
  startTime: string | null;

  @Column({ name: 'time_zone', type: 'text', default: 'Asia/Kolkata' })
  timeZone: string;

  @Column({ type: 'text' })
  city: string;

  @Column({ name: 'venue_name', type: 'text', nullable: true })
  venueName: string | null;

  @Column({ name: 'venue_address', type: 'text', nullable: true })
  venueAddress: string | null;

  @Column({ name: 'guest_count_estimate', type: 'integer', nullable: true })
  guestCountEstimate: number | null;

  /** numeric(12,2) rupees as a string (ADR-0014). */
  @Column({
    name: 'total_budget_amount',
    type: 'numeric',
    precision: 12,
    scale: 2,
    nullable: true,
  })
  totalBudgetAmount: string | null;

  @Column({ type: 'text', default: 'INR' })
  currency: string;

  /** Cover photo (M10) — a READY `media` row of kind EVENT_COVER. */
  @Column({ name: 'cover_media_id', type: 'uuid', nullable: true })
  coverMediaId: string | null;

  @Column({ type: 'text', default: 'PLANNING' })
  status: EventStatus;

  @Column({ name: 'status_changed_at', type: 'timestamptz' })
  statusChangedAt: Date;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
