import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
  VersionColumn,
} from 'typeorm';

export type InvitationStatus = 'DRAFT' | 'PUBLISHED' | 'REVOKED';

/** An event's e-invitation (R9, domain-model.md §4.14). One per event. */
@Entity('invitations')
export class InvitationEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'template_code', type: 'text' })
  templateCode: string;

  @Column({ type: 'text' })
  title: string;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  @Column({ name: 'host_names', type: 'text', nullable: true })
  hostNames: string | null;

  /** Snapshot of the event details when the invitation was last saved. */
  @Column({ name: 'event_date', type: 'date' })
  eventDate: string;

  @Column({ name: 'start_time', type: 'time', nullable: true })
  startTime: string | null;

  @Column({ name: 'venue_name', type: 'text', nullable: true })
  venueName: string | null;

  @Column({ name: 'venue_address', type: 'text', nullable: true })
  venueAddress: string | null;

  @Column({ type: 'text', default: 'DRAFT' })
  status: InvitationStatus;

  @Column({ name: 'rsvp_open', type: 'boolean', default: true })
  rsvpOpen: boolean;

  /** SHA-256 of the share token; the token itself is never stored. */
  @Column({ name: 'share_token_hash', type: 'bytea', nullable: true })
  shareTokenHash: Buffer | null;

  @Column({ name: 'published_at', type: 'timestamptz', nullable: true })
  publishedAt: Date | null;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @Column({
    name: 'last_rsvp_notified_at',
    type: 'timestamptz',
    nullable: true,
  })
  lastRsvpNotifiedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @VersionColumn()
  version: number;
}
