import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

/** Planned amount for one vendor category of one event (domain §7). */
@Entity('budget_allocations')
export class BudgetAllocationEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'category_id', type: 'uuid' })
  categoryId: string;

  /** numeric(12,2) rupees as a string (ADR-0014). */
  @Column({
    name: 'planned_amount',
    type: 'numeric',
    precision: 12,
    scale: 2,
  })
  plannedAmount: string;

  @Column({ type: 'text', default: 'INR' })
  currency: string;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
