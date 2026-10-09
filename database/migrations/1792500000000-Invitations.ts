import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M19 (R9, A6): one e-invitation per event and its anonymous RSVPs.
 * Share and responder tokens are stored only as SHA-256 hashes
 * (architecture/media-and-deep-links.md §5).
 */
export class Invitations1792500000000 implements MigrationInterface {
  name = 'Invitations1792500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE invitations (
        id uuid PRIMARY KEY,
        event_id uuid NOT NULL,
        user_id uuid NOT NULL,
        template_code text NOT NULL,
        title text NOT NULL,
        message text,
        host_names text,
        event_date date NOT NULL,
        start_time time,
        venue_name text,
        venue_address text,
        status text NOT NULL DEFAULT 'DRAFT',
        rsvp_open boolean NOT NULL DEFAULT true,
        share_token_hash bytea,
        published_at timestamptz,
        revoked_at timestamptz,
        last_rsvp_notified_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_invitations_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT fk_invitations_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT uq_invitations_event_id UNIQUE (event_id),
        CONSTRAINT uq_invitations_share_token_hash UNIQUE (share_token_hash),
        CONSTRAINT ck_invitations_template_code CHECK (template_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(template_code) <= 40),
        CONSTRAINT ck_invitations_title CHECK (char_length(title) BETWEEN 1 AND 120),
        CONSTRAINT ck_invitations_message CHECK (message IS NULL OR char_length(message) BETWEEN 1 AND 1000),
        CONSTRAINT ck_invitations_host_names CHECK (host_names IS NULL OR char_length(host_names) BETWEEN 1 AND 200),
        CONSTRAINT ck_invitations_status CHECK (status IN ('DRAFT','PUBLISHED','REVOKED')),
        CONSTRAINT ck_invitations_published CHECK (status <> 'PUBLISHED' OR (share_token_hash IS NOT NULL AND published_at IS NOT NULL)),
        CONSTRAINT ck_invitations_revoked CHECK ((status = 'REVOKED') = (revoked_at IS NOT NULL))
      )`);
    await queryRunner.query(`
      CREATE TABLE invitation_rsvps (
        id uuid PRIMARY KEY,
        invitation_id uuid NOT NULL,
        responder_token_hash bytea NOT NULL,
        guest_name text NOT NULL,
        response text NOT NULL,
        guest_count integer NOT NULL DEFAULT 1,
        message text,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_invitation_rsvps_invitation_id FOREIGN KEY (invitation_id) REFERENCES invitations (id) ON DELETE RESTRICT,
        CONSTRAINT uq_invitation_rsvps_invitation_id_responder UNIQUE (invitation_id, responder_token_hash),
        CONSTRAINT ck_invitation_rsvps_guest_name CHECK (char_length(guest_name) BETWEEN 1 AND 80),
        CONSTRAINT ck_invitation_rsvps_response CHECK (response IN ('ATTENDING','NOT_ATTENDING','MAYBE')),
        CONSTRAINT ck_invitation_rsvps_guest_count CHECK (guest_count BETWEEN 1 AND 20),
        CONSTRAINT ck_invitation_rsvps_message CHECK (message IS NULL OR char_length(message) BETWEEN 1 AND 500)
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_invitation_rsvps_invitation_id_updated_at ON invitation_rsvps (invitation_id, updated_at DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE invitation_rsvps`);
    await queryRunner.query(`DROP TABLE invitations`);
  }
}
