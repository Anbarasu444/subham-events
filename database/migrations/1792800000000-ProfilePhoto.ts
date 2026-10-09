import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M21: a user profile photo (private ImageKit media like event covers).
 * Media gains the USER owner and USER_PHOTO kind.
 */
export class ProfilePhoto1792800000000 implements MigrationInterface {
  name = 'ProfilePhoto1792800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE media DROP CONSTRAINT ck_media_owner_type`,
    );
    await queryRunner.query(
      `ALTER TABLE media ADD CONSTRAINT ck_media_owner_type CHECK (owner_type IN ('EVENT', 'USER'))`,
    );
    await queryRunner.query(`ALTER TABLE media DROP CONSTRAINT ck_media_kind`);
    await queryRunner.query(
      `ALTER TABLE media ADD CONSTRAINT ck_media_kind CHECK (kind IN ('EVENT_COVER', 'USER_PHOTO'))`,
    );
    await queryRunner.query(`ALTER TABLE users ADD COLUMN photo_media_id uuid`);
    await queryRunner.query(
      `ALTER TABLE users ADD CONSTRAINT fk_users_photo_media_id FOREIGN KEY (photo_media_id) REFERENCES media (id) ON DELETE RESTRICT`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE users DROP CONSTRAINT fk_users_photo_media_id`,
    );
    await queryRunner.query(`ALTER TABLE users DROP COLUMN photo_media_id`);
    await queryRunner.query(`ALTER TABLE media DROP CONSTRAINT ck_media_kind`);
    await queryRunner.query(
      `ALTER TABLE media ADD CONSTRAINT ck_media_kind CHECK (kind IN ('EVENT_COVER'))`,
    );
    await queryRunner.query(
      `ALTER TABLE media DROP CONSTRAINT ck_media_owner_type`,
    );
    await queryRunner.query(
      `ALTER TABLE media ADD CONSTRAINT ck_media_owner_type CHECK (owner_type IN ('EVENT'))`,
    );
  }
}
