import { Column, Entity, PrimaryColumn } from 'typeorm';

export type IdempotencyPrincipalType = 'USER' | 'ADMIN';
export type IdempotencyStatus = 'IN_PROGRESS' | 'COMPLETED';

/** Stored request outcome for safe client retries (api-contracts.md §9). */
@Entity('idempotency_keys')
export class IdempotencyKeyEntity {
  @PrimaryColumn({ name: 'principal_type', type: 'text' })
  principalType: IdempotencyPrincipalType;

  @PrimaryColumn({ name: 'principal_id', type: 'uuid' })
  principalId: string;

  @PrimaryColumn({ type: 'text' })
  key: string;

  @Column({ type: 'text' })
  route: string;

  @Column({ name: 'request_hash', type: 'text' })
  requestHash: string;

  @Column({ type: 'text' })
  status: IdempotencyStatus;

  @Column({ name: 'response_status', type: 'integer', nullable: true })
  responseStatus: number | null;

  @Column({ name: 'response_body', type: 'jsonb', nullable: true })
  responseBody: unknown;

  @Column({ name: 'created_at', type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;
}
