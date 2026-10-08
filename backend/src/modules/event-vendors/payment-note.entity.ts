import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export const PAYMENT_KINDS = [
  'ADVANCE',
  'INSTALMENT',
  'FINAL',
  'OTHER',
] as const;
export type PaymentKind = (typeof PAYMENT_KINDS)[number];
export const PAYMENT_METHODS = [
  'CASH',
  'UPI',
  'BANK_TRANSFER',
  'CARD',
  'CHEQUE',
  'OTHER',
] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

/**
 * The user's private note of a payment to a booked vendor (R5, A2, A3).
 * A record only: no money moves and nothing is verified.
 */
@Entity('event_payment_notes')
export class PaymentNoteEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'booking_id', type: 'uuid' })
  bookingId: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'text' })
  kind: PaymentKind;

  /** numeric(12,2) rupees as a string (ADR-0014); > 0. */
  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: string;

  @Column({ type: 'text', default: 'INR' })
  currency: string;

  /** Calendar date the money was paid. */
  @Column({ name: 'paid_on', type: 'date' })
  paidOn: string;

  @Column({ type: 'text' })
  method: PaymentMethod;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
