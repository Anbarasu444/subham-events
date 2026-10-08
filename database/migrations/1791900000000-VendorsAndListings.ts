import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M12 (read side; written by the Vendor App M26–M28 and admins M40+):
 * vendors and their category listings (database-schema.md Part C.2).
 * Location is a city plus service areas (O2). Starting prices are
 * marketplace information only, never budget figures (ADR-0014 money).
 * Listing media (M28), submissions and fees (M29/M30) come later.
 */
export class VendorsAndListings1791900000000 implements MigrationInterface {
  name = 'VendorsAndListings1791900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE vendors (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        business_name text NOT NULL,
        description text,
        phone text,
        email text,
        city text NOT NULL,
        service_areas text[] NOT NULL DEFAULT '{}',
        logo_media_id uuid,
        status text NOT NULL DEFAULT 'ACTIVE',
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_vendors_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_vendors_logo_media_id FOREIGN KEY (logo_media_id) REFERENCES media (id) ON DELETE RESTRICT,
        CONSTRAINT uq_vendors_user_id UNIQUE (user_id),
        CONSTRAINT ck_vendors_business_name CHECK (char_length(business_name) BETWEEN 1 AND 120),
        CONSTRAINT ck_vendors_description CHECK (description IS NULL OR char_length(description) BETWEEN 1 AND 2000),
        CONSTRAINT ck_vendors_city CHECK (char_length(city) BETWEEN 1 AND 80),
        CONSTRAINT ck_vendors_service_areas CHECK (cardinality(service_areas) <= 30),
        CONSTRAINT ck_vendors_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
        CONSTRAINT ck_vendors_deleted_at CHECK ((status = 'DELETED') = (deleted_at IS NOT NULL))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_vendors_city ON vendors (lower(city)) WHERE status = 'ACTIVE'`,
    );

    await queryRunner.query(`
      CREATE TABLE vendor_listings (
        id uuid PRIMARY KEY,
        vendor_id uuid NOT NULL,
        category_id uuid NOT NULL,
        title text NOT NULL,
        description text,
        starting_price_amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        city text NOT NULL,
        service_areas text[] NOT NULL DEFAULT '{}',
        status text NOT NULL DEFAULT 'DRAFT',
        rejection_reason text,
        approved_at timestamptz,
        approved_by_admin_id uuid,
        pending_revision jsonb,
        rating_count integer NOT NULL DEFAULT 0,
        rating_sum integer NOT NULL DEFAULT 0,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_vendor_listings_vendor_id FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE RESTRICT,
        CONSTRAINT fk_vendor_listings_category_id FOREIGN KEY (category_id) REFERENCES vendor_categories (id) ON DELETE RESTRICT,
        CONSTRAINT uq_vendor_listings_vendor_id_category_id UNIQUE (vendor_id, category_id),
        CONSTRAINT ck_vendor_listings_title CHECK (char_length(title) BETWEEN 1 AND 120),
        CONSTRAINT ck_vendor_listings_description CHECK (description IS NULL OR char_length(description) BETWEEN 1 AND 4000),
        CONSTRAINT ck_vendor_listings_starting_price_amount CHECK (starting_price_amount >= 0),
        CONSTRAINT ck_vendor_listings_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_vendor_listings_city CHECK (char_length(city) BETWEEN 1 AND 80),
        CONSTRAINT ck_vendor_listings_service_areas CHECK (cardinality(service_areas) <= 30),
        CONSTRAINT ck_vendor_listings_status CHECK (status IN ('DRAFT', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'SUSPENDED', 'ARCHIVED')),
        CONSTRAINT ck_vendor_listings_approved_at CHECK (status <> 'APPROVED' OR approved_at IS NOT NULL),
        CONSTRAINT ck_vendor_listings_rating CHECK (rating_count >= 0 AND rating_sum BETWEEN rating_count AND rating_count * 5)
      )`);
    // Discovery reads APPROVED listings only: by category and city, newest
    // first, or by starting price.
    await queryRunner.query(
      `CREATE INDEX ix_vendor_listings_category_id_status_city ON vendor_listings (category_id, lower(city)) WHERE status = 'APPROVED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_vendor_listings_approved_at ON vendor_listings (approved_at DESC, id DESC) WHERE status = 'APPROVED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_vendor_listings_starting_price_amount ON vendor_listings (starting_price_amount, id) WHERE status = 'APPROVED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_vendor_listings_vendor_id ON vendor_listings (vendor_id)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE vendor_listings`);
    await queryRunner.query(`DROP TABLE vendors`);
  }
}
