import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

/** Stored states; EXPIRED is derived from `validUntil` (R3). */
export type QuotationStatus =
  'SENT' | 'ACCEPTED' | 'REJECTED' | 'SUPERSEDED' | 'WITHDRAWN';

/** A vendor's price offer for an enquiry (domain-model.md §4.9, R3). */
@Entity('quotations')
export class QuotationEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'enquiry_id', type: 'uuid' })
  enquiryId: string;

  @Column({ name: 'event_vendor_id', type: 'uuid' })
  eventVendorId: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'vendor_id', type: 'uuid' })
  vendorId: string;

  /** numeric(12,2) rupees as a string (ADR-0014); > 0. */
  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: string;

  @Column({ type: 'text', default: 'INR' })
  currency: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  /** Calendar date; null = valid until the event date. */
  @Column({ name: 'valid_until', type: 'date', nullable: true })
  validUntil: string | null;

  @Column({ name: 'revision_no', type: 'integer', default: 1 })
  revisionNo: number;

  @Column({ type: 'text', default: 'SENT' })
  status: QuotationStatus;

  @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
  respondedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
