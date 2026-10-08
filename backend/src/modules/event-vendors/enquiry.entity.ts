import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export type EnquiryStatus = 'OPEN' | 'QUOTED' | 'DECLINED' | 'CLOSED';
export type EnquiryClosedBy = 'USER' | 'VENDOR' | 'SYSTEM';

/** A user's enquiry to a vendor for an event (domain-model.md §4.8). */
@Entity('enquiries')
export class EnquiryEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_vendor_id', type: 'uuid' })
  eventVendorId: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'vendor_id', type: 'uuid' })
  vendorId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'text' })
  message: string;

  /** Calendar date `YYYY-MM-DD`, optional. */
  @Column({ name: 'preferred_date', type: 'date', nullable: true })
  preferredDate: string | null;

  @Column({ type: 'text', default: 'OPEN' })
  status: EnquiryStatus;

  @Column({ name: 'decline_reason', type: 'text', nullable: true })
  declineReason: string | null;

  @Column({ name: 'closed_by_type', type: 'text', nullable: true })
  closedByType: EnquiryClosedBy | null;

  @Column({ name: 'closed_at', type: 'timestamptz', nullable: true })
  closedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
