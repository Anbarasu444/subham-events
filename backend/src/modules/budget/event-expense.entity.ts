import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

/**
 * One of the owner's own expenses for an event (M11, user answer 5): a note
 * of money spent outside platform bookings. No money moves through it.
 */
@Entity('event_expenses')
export class EventExpenseEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ type: 'text' })
  title: string;

  /** numeric(12,2) rupees as a string (ADR-0014); always > 0. */
  @Column({ type: 'numeric', precision: 12, scale: 2 })
  amount: string;

  @Column({ type: 'text', default: 'INR' })
  currency: string;

  /** Calendar date `YYYY-MM-DD` the money was spent. */
  @Column({ name: 'spent_on', type: 'date' })
  spentOn: string;

  @Column({ name: 'category_id', type: 'uuid', nullable: true })
  categoryId: string | null;

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
