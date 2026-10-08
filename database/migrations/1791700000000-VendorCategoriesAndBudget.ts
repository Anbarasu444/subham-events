import type { MigrationInterface, QueryRunner } from 'typeorm';

/** Starter vendor categories (M11 spec, open question 2 proposal). */
const STARTER_CATEGORIES: [slug: string, name: string][] = [
  ['venue', 'Venue'],
  ['catering', 'Catering'],
  ['decoration', 'Decoration'],
  ['photography', 'Photography'],
  ['videography', 'Videography'],
  ['makeup-mehendi', 'Makeup & Mehendi'],
  ['music-dj', 'Music & DJ'],
  ['invitations-printing', 'Invitations & Printing'],
  ['transport', 'Transport'],
  ['gifts-return-gifts', 'Gifts & Return Gifts'],
  ['priest-rituals', 'Priest & Rituals'],
  ['other-services', 'Other services'],
];

/**
 * M11: vendor categories (shared with vendor discovery M12 and admin M42;
 * database-schema.md Part C) with a starter seed, and per-event budget
 * allocations (domain-model.md §7). Money is numeric(12,2) (ADR-0014).
 */
export class VendorCategoriesAndBudget1791700000000 implements MigrationInterface {
  name = 'VendorCategoriesAndBudget1791700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE vendor_categories (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name text NOT NULL,
        slug text NOT NULL,
        description text,
        status text NOT NULL DEFAULT 'DRAFT',
        sort_order integer NOT NULL DEFAULT 0,
        created_by_admin_id uuid,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT uq_vendor_categories_slug UNIQUE (slug),
        CONSTRAINT ck_vendor_categories_name CHECK (char_length(name) BETWEEN 1 AND 80),
        CONSTRAINT ck_vendor_categories_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
        CONSTRAINT ck_vendor_categories_status CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_vendor_categories_status_sort_order ON vendor_categories (status, sort_order)`,
    );
    // Reference data; idempotent by slug.
    for (const [index, [slug, name]] of STARTER_CATEGORIES.entries()) {
      await queryRunner.query(
        `INSERT INTO vendor_categories (slug, name, status, sort_order)
         VALUES ($1, $2, 'PUBLISHED', $3)
         ON CONFLICT (slug) DO NOTHING`,
        [slug, name, (index + 1) * 10],
      );
    }

    await queryRunner.query(`
      CREATE TABLE budget_allocations (
        id uuid PRIMARY KEY,
        event_id uuid NOT NULL,
        category_id uuid NOT NULL,
        planned_amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_budget_allocations_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT fk_budget_allocations_category_id FOREIGN KEY (category_id) REFERENCES vendor_categories (id) ON DELETE RESTRICT,
        CONSTRAINT ck_budget_allocations_planned_amount CHECK (planned_amount >= 0),
        CONSTRAINT ck_budget_allocations_currency CHECK (currency IN ('INR'))
      )`);
    // One live allocation per event and category (cleared rows are kept, R11).
    await queryRunner.query(
      `CREATE UNIQUE INDEX uq_budget_allocations_event_id_category_id ON budget_allocations (event_id, category_id) WHERE deleted_at IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE budget_allocations`);
    await queryRunner.query(`DROP TABLE vendor_categories`);
  }
}
