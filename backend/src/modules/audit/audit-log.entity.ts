import { Column, Entity, PrimaryColumn } from 'typeorm';

export const ACTOR_TYPES = [
  'USER',
  'VENDOR',
  'ADMIN',
  'SYSTEM',
  'PROVIDER',
  'GUEST',
] as const;
export type ActorType = (typeof ACTOR_TYPES)[number];

/** Append-only audit trail (database-schema.md §10). Never updated or deleted. */
@Entity('audit_logs')
export class AuditLogEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'occurred_at', type: 'timestamptz', default: () => 'now()' })
  occurredAt: Date;

  @Column({ name: 'actor_type', type: 'text' })
  actorType: ActorType;

  @Column({ name: 'actor_id', type: 'uuid', nullable: true })
  actorId: string | null;

  @Column({ name: 'actor_role', type: 'text', nullable: true })
  actorRole: string | null;

  @Column({ type: 'text' })
  action: string;

  @Column({ name: 'entity_type', type: 'text' })
  entityType: string;

  @Column({ name: 'entity_id', type: 'uuid', nullable: true })
  entityId: string | null;

  @Column({ name: 'request_id', type: 'text', nullable: true })
  requestId: string | null;

  @Column({ type: 'inet', nullable: true })
  ip: string | null;

  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  summary: Record<string, unknown>;

  @Column({ type: 'text', nullable: true })
  reason: string | null;
}
