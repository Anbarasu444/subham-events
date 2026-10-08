import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M10: media metadata for ImageKit files (ADR-0007, database-schema.md
 * Part C, media-and-deep-links.md §3) and the event cover photo. Only the
 * kinds/owners used so far are allowed; later milestones extend the checks.
 * Soft delete only (R11): rows and ImageKit files are kept, not served.
 */
export class MediaAndEventCover1791600000000 implements MigrationInterface {
  name = 'MediaAndEventCover1791600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE media (
        id uuid PRIMARY KEY,
        owner_type text NOT NULL,
        owner_id uuid NOT NULL,
        kind text NOT NULL,
        status text NOT NULL DEFAULT 'PENDING_UPLOAD',
        folder text NOT NULL,
        file_name text NOT NULL,
        imagekit_file_id text,
        file_path text,
        content_type text,
        size_bytes integer,
        width integer,
        height integer,
        rejection_reason text,
        uploaded_by_type text NOT NULL,
        uploaded_by_id uuid NOT NULL,
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_media_imagekit_file_id UNIQUE (imagekit_file_id),
        CONSTRAINT ck_media_owner_type CHECK (owner_type IN ('EVENT')),
        CONSTRAINT ck_media_kind CHECK (kind IN ('EVENT_COVER')),
        CONSTRAINT ck_media_status CHECK (status IN ('PENDING_UPLOAD', 'READY', 'REJECTED')),
        CONSTRAINT ck_media_uploaded_by_type CHECK (uploaded_by_type IN ('USER', 'VENDOR', 'ADMIN')),
        CONSTRAINT ck_media_size_bytes CHECK (size_bytes IS NULL OR size_bytes BETWEEN 1 AND 31457280),
        CONSTRAINT ck_media_ready CHECK (
          status <> 'READY' OR (imagekit_file_id IS NOT NULL AND file_path IS NOT NULL
                                AND content_type IS NOT NULL AND size_bytes IS NOT NULL))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_media_owner_type_owner_id ON media (owner_type, owner_id) WHERE deleted_at IS NULL`,
    );
    // Clean-up job: abandoned PENDING_UPLOAD rows.
    await queryRunner.query(
      `CREATE INDEX ix_media_status_created_at ON media (status, created_at) WHERE status = 'PENDING_UPLOAD'`,
    );

    await queryRunner.query(
      `ALTER TABLE events ADD COLUMN cover_media_id uuid`,
    );
    await queryRunner.query(
      `ALTER TABLE events ADD CONSTRAINT fk_events_cover_media_id FOREIGN KEY (cover_media_id) REFERENCES media (id) ON DELETE RESTRICT`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE events DROP CONSTRAINT fk_events_cover_media_id`,
    );
    await queryRunner.query(`ALTER TABLE events DROP COLUMN cover_media_id`);
    await queryRunner.query(`DROP TABLE media`);
  }
}
