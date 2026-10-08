import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M14: saved listings, the event ↔ listing relationship (event vendors,
 * domain-model.md §4.7) and enquiries (§4.8). Denormalised owner columns are
 * protected by composite foreign keys (invariant 13). Agreed amounts live on
 * bookings (M15), never here.
 */
export class WishlistEventVendorsEnquiries1792000000000
  implements MigrationInterface
{
  name = 'WishlistEventVendorsEnquiries1792000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE wishlist_items (
        user_id uuid NOT NULL,
        listing_id uuid NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz,
        CONSTRAINT pk_wishlist_items PRIMARY KEY (user_id, listing_id),
        CONSTRAINT fk_wishlist_items_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_wishlist_items_listing_id FOREIGN KEY (listing_id) REFERENCES vendor_listings (id) ON DELETE RESTRICT
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_wishlist_items_user_id_created_at ON wishlist_items (user_id, created_at DESC) WHERE deleted_at IS NULL`,
    );

    await queryRunner.query(`
      CREATE TABLE event_vendors (
        id uuid PRIMARY KEY,
        event_id uuid NOT NULL,
        listing_id uuid NOT NULL,
        vendor_id uuid NOT NULL,
        category_id uuid NOT NULL,
        status text NOT NULL DEFAULT 'ADDED',
        notes text,
        status_changed_at timestamptz NOT NULL DEFAULT now(),
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_event_vendors_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT fk_event_vendors_listing_id FOREIGN KEY (listing_id) REFERENCES vendor_listings (id) ON DELETE RESTRICT,
        CONSTRAINT fk_event_vendors_vendor_id FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE RESTRICT,
        CONSTRAINT fk_event_vendors_category_id FOREIGN KEY (category_id) REFERENCES vendor_categories (id) ON DELETE RESTRICT,
        CONSTRAINT uq_event_vendors_id_event_id_vendor_id UNIQUE (id, event_id, vendor_id),
        CONSTRAINT ck_event_vendors_status CHECK (status IN ('ADDED','ENQUIRED','QUOTED','BOOKED','COMPLETED','CANCELLED','REMOVED')),
        CONSTRAINT ck_event_vendors_notes CHECK (notes IS NULL OR char_length(notes) BETWEEN 1 AND 1000)
      )`);
    // The same listing once per event; a removed one may be added again.
    await queryRunner.query(
      `CREATE UNIQUE INDEX uq_event_vendors_event_id_listing_id ON event_vendors (event_id, listing_id) WHERE status <> 'REMOVED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_event_vendors_event_id ON event_vendors (event_id, created_at)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_event_vendors_vendor_id_status ON event_vendors (vendor_id, status)`,
    );

    await queryRunner.query(`
      CREATE TABLE enquiries (
        id uuid PRIMARY KEY,
        event_vendor_id uuid NOT NULL,
        event_id uuid NOT NULL,
        vendor_id uuid NOT NULL,
        user_id uuid NOT NULL,
        message text NOT NULL,
        preferred_date date,
        status text NOT NULL DEFAULT 'OPEN',
        decline_reason text,
        closed_by_type text,
        closed_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_enquiries_event_vendor FOREIGN KEY (event_vendor_id, event_id, vendor_id)
          REFERENCES event_vendors (id, event_id, vendor_id) ON DELETE RESTRICT,
        CONSTRAINT fk_enquiries_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_enquiries_message CHECK (char_length(message) BETWEEN 10 AND 1000),
        CONSTRAINT ck_enquiries_status CHECK (status IN ('OPEN','QUOTED','DECLINED','CLOSED')),
        CONSTRAINT ck_enquiries_closed_by_type CHECK (closed_by_type IS NULL OR closed_by_type IN ('USER','VENDOR','SYSTEM')),
        CONSTRAINT ck_enquiries_closed CHECK ((status IN ('DECLINED','CLOSED')) = (closed_at IS NOT NULL))
      )`);
    // One live (open or quoted) enquiry per event vendor.
    await queryRunner.query(
      `CREATE UNIQUE INDEX uq_enquiries_event_vendor_id_live ON enquiries (event_vendor_id) WHERE status IN ('OPEN','QUOTED')`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_enquiries_vendor_id_status_created_at ON enquiries (vendor_id, status, created_at DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_enquiries_user_id_created_at ON enquiries (user_id, created_at DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_enquiries_event_id ON enquiries (event_id)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE enquiries`);
    await queryRunner.query(`DROP TABLE event_vendors`);
    await queryRunner.query(`DROP TABLE wishlist_items`);
  }
}
