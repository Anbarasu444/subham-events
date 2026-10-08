import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export const EVENT_VENDOR_STATUSES = [
  'ADDED',
  'ENQUIRED',
  'QUOTED',
  'BOOKED',
  'COMPLETED',
  'CANCELLED',
  'REMOVED',
] as const;
export type EventVendorStatus = (typeof EVENT_VENDOR_STATUSES)[number];

/**
 * A platform listing engaged for an event (domain-model.md §4.7). Holds no
 * amounts: the agreed amount lives on the booking (M15).
 */
@Entity('event_vendors')
export class EventVendorEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'listing_id', type: 'uuid' })
  listingId: string;

  /** Copied from the listing server-side (vendor queries, M32). */
  @Column({ name: 'vendor_id', type: 'uuid' })
  vendorId: string;

  /** Copied from the listing server-side (budget grouping, M15). */
  @Column({ name: 'category_id', type: 'uuid' })
  categoryId: string;

  @Column({ type: 'text', default: 'ADDED' })
  status: EventVendorStatus;

  /** Private to the event owner (A9: never shown to the vendor). */
  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ name: 'status_changed_at', type: 'timestamptz' })
  statusChangedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
