import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

export type MediaOwnerType = 'EVENT' | 'USER';
export type MediaKind = 'EVENT_COVER' | 'USER_PHOTO';
export type MediaStatus = 'PENDING_UPLOAD' | 'READY' | 'REJECTED';

/** Metadata of one ImageKit file (bytes live in ImageKit — ADR-0007). */
@Entity('media')
export class MediaEntity {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'owner_type', type: 'text' })
  ownerType: MediaOwnerType;

  @Column({ name: 'owner_id', type: 'uuid' })
  ownerId: string;

  @Column({ type: 'text' })
  kind: MediaKind;

  @Column({ type: 'text', default: 'PENDING_UPLOAD' })
  status: MediaStatus;

  /** Fixed by the backend before upload; the file must end up exactly here. */
  @Column({ type: 'text' })
  folder: string;

  @Column({ name: 'file_name', type: 'text' })
  fileName: string;

  @Column({ name: 'imagekit_file_id', type: 'text', nullable: true })
  imagekitFileId: string | null;

  @Column({ name: 'file_path', type: 'text', nullable: true })
  filePath: string | null;

  @Column({ name: 'content_type', type: 'text', nullable: true })
  contentType: string | null;

  @Column({ name: 'size_bytes', type: 'integer', nullable: true })
  sizeBytes: number | null;

  @Column({ type: 'integer', nullable: true })
  width: number | null;

  @Column({ type: 'integer', nullable: true })
  height: number | null;

  @Column({ name: 'rejection_reason', type: 'text', nullable: true })
  rejectionReason: string | null;

  @Column({ name: 'uploaded_by_type', type: 'text' })
  uploadedByType: 'USER' | 'VENDOR' | 'ADMIN';

  @Column({ name: 'uploaded_by_id', type: 'uuid' })
  uploadedById: string;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
