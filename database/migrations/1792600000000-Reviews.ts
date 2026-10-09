import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M20 (R7, A4, A5, A12): one review per completed booking. The rating is
 * public at once and counts toward `vendor_listings.rating_sum/count`; the
 * comment waits for admin moderation (screens in M51).
 */
export class Reviews1792600000000 implements MigrationInterface {
  name = 'Reviews1792600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE reviews (
        id uuid PRIMARY KEY,
        booking_id uuid NOT NULL,
        user_id uuid NOT NULL,
        vendor_id uuid NOT NULL,
        listing_id uuid NOT NULL,
        rating smallint NOT NULL,
        rating_status text NOT NULL DEFAULT 'ACTIVE',
        rating_removed_reason text,
        comment text,
        comment_status text NOT NULL DEFAULT 'NONE',
        moderated_by_admin_id uuid,
        moderated_at timestamptz,
        moderation_reason text,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_reviews_booking_id FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE RESTRICT,
        CONSTRAINT fk_reviews_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_reviews_vendor_id FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE RESTRICT,
        CONSTRAINT fk_reviews_listing_id FOREIGN KEY (listing_id) REFERENCES vendor_listings (id) ON DELETE RESTRICT,
        CONSTRAINT uq_reviews_booking_id UNIQUE (booking_id),
        CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5),
        CONSTRAINT ck_reviews_rating_status CHECK (rating_status IN ('ACTIVE','REMOVED')),
        CONSTRAINT ck_reviews_rating_removed CHECK ((rating_status = 'REMOVED') = (rating_removed_reason IS NOT NULL)),
        CONSTRAINT ck_reviews_comment CHECK (comment IS NULL OR char_length(comment) BETWEEN 1 AND 1000),
        CONSTRAINT ck_reviews_comment_status CHECK (comment_status IN ('NONE','PENDING_MODERATION','APPROVED','REJECTED','HIDDEN')),
        CONSTRAINT ck_reviews_comment_presence CHECK ((comment IS NULL) = (comment_status = 'NONE')),
        CONSTRAINT ck_reviews_moderated CHECK (comment_status NOT IN ('APPROVED','REJECTED','HIDDEN') OR moderated_at IS NOT NULL),
        CONSTRAINT ck_reviews_moderation_reason CHECK (moderation_reason IS NULL OR char_length(moderation_reason) BETWEEN 1 AND 500)
      )`);
    // Public list: approved comments of a listing, newest first.
    await queryRunner.query(
      `CREATE INDEX ix_reviews_listing_id_created_at ON reviews (listing_id, created_at DESC, id DESC) WHERE comment_status = 'APPROVED' AND rating_status = 'ACTIVE'`,
    );
    // Star breakdown per listing.
    await queryRunner.query(
      `CREATE INDEX ix_reviews_listing_id_rating ON reviews (listing_id, rating) WHERE rating_status = 'ACTIVE'`,
    );
    // Admin moderation queue (M51).
    await queryRunner.query(
      `CREATE INDEX ix_reviews_comment_status_created_at ON reviews (created_at) WHERE comment_status = 'PENDING_MODERATION'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_reviews_user_id_created_at ON reviews (user_id, created_at DESC, id DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_reviews_vendor_id ON reviews (vendor_id)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE reviews`);
  }
}
