import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export const CHECKLIST_STATUSES = ['PENDING', 'DONE'] as const;
export type ChecklistStatus = (typeof CHECKLIST_STATUSES)[number];

/** One task of an event's checklist, written by the owner (R8, §4.12). */
@Entity('checklist_items')
export class ChecklistItemEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ type: 'text' })
  title: string;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  /** Calendar date `YYYY-MM-DD` in the event's time zone. */
  @Column({ name: 'due_date', type: 'date', nullable: true })
  dueDate: string | null;

  @Column({ type: 'text', default: 'PENDING' })
  status: ChecklistStatus;

  @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
  completedAt: Date | null;

  @Column({ name: 'sort_order', type: 'integer' })
  sortOrder: number;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
