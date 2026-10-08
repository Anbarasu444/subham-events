import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export type BookingStatus = 'CONFIRMED' | 'CANCELLED' | 'COMPLETED';
export type BookingCancelledBy = 'USER' | 'VENDOR' | 'ADMIN';

/**
 * A confirmed engagement (domain-model.md §4.10, A7). `agreedAmount` is
 * copied from the accepted quotation and never changes: it is the only
 * authoritative "agreed budget" (never the listing's starting price).
 */
@Entity('bookings')
export class BookingEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_vendor_id', type: 'uuid' })
  eventVendorId: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'vendor_id', type: 'uuid' })
  vendorId: string;

  @Column({ name: 'quotation_id', type: 'uuid' })
  quotationId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({
    name: 'agreed_amount',
    type: 'numeric',
    precision: 12,
    scale: 2,
    update: false,
  })
  agreedAmount: string;

  @Column({ type: 'text', default: 'INR', update: false })
  currency: string;

  /** Calendar date of the service. */
  @Column({ name: 'service_date', type: 'date' })
  serviceDate: string;

  @Column({ type: 'text', default: 'CONFIRMED' })
  status: BookingStatus;

  @Column({ name: 'cancelled_by_type', type: 'text', nullable: true })
  cancelledByType: BookingCancelledBy | null;

  @Column({ name: 'cancel_reason', type: 'text', nullable: true })
  cancelReason: string | null;

  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
  cancelledAt: Date | null;

  @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
  completedAt: Date | null;

  @Column({ name: 'status_changed_at', type: 'timestamptz' })
  statusChangedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
