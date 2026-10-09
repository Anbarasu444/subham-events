import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  DataSource,
  IsNull,
  LessThan,
  QueryFailedError,
  type Repository,
} from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { AuditService } from '../audit/audit.service';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import {
  COVER_MAX_BYTES,
  IMAGE_TYPES,
  type CreateUploadDto,
  type UploadIntentDto,
} from './media.dto';
import { MediaEntity } from './media.entity';
import {
  IMAGEKIT_UPLOAD_URL,
  ImageKitClient,
  type ImageKitFile,
} from './imagekit.client';

/** Abandoned uploads are rejected (and their files removed) after this. */
export const PENDING_UPLOAD_TTL_MS = 24 * 60 * 60 * 1000;
/** Open (not yet completed) uploads allowed per event at a time. */
export const MAX_PENDING_PER_EVENT = 3;
const CLEANUP_BATCH = 100;

type Problem =
  | 'NOT_FOUND'
  | 'WRONG_PATH'
  | 'NOT_PRIVATE'
  | 'TYPE_NOT_ALLOWED'
  | 'EMPTY'
  | 'TOO_LARGE';

/**
 * Upload flow (media-and-deep-links.md §3): the backend issues a single-use
 * v2 upload token that fixes folder, name and privacy; the app uploads
 * straight to ImageKit; the backend then verifies the stored file before it
 * can be used.
 */
@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(
    @InjectRepository(MediaEntity)
    private readonly media: Repository<MediaEntity>,
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly imageKit: ImageKitClient,
    private readonly audit: AuditService,
    private readonly dataSource: DataSource,
  ) {}

  async createUpload(
    userId: string,
    dto: CreateUploadDto,
    now = new Date(),
  ): Promise<UploadIntentDto> {
    this.assertEnabled();
    const owner = await this.ownerOf(userId, dto);
    const id = uuidv7();
    // No user-provided names in paths (§2): /{root}/{kind}/{owner}/{id}.{ext}
    const folder =
      owner.type === 'EVENT'
        ? `${this.imageKit.rootFolder}/event-cover/event/${owner.id}`
        : `${this.imageKit.rootFolder}/user-photo/user/${owner.id}`;
    const fileName = `${id}.${IMAGE_TYPES[dto.contentType]}`;
    await this.dataSource.transaction(async (manager) => {
      // The owner row lock makes count-then-insert atomic per owner.
      await manager.query(
        owner.type === 'EVENT'
          ? `SELECT 1 FROM events WHERE id = $1 FOR UPDATE`
          : `SELECT 1 FROM users WHERE id = $1 FOR UPDATE`,
        [owner.id],
      );
      const open = await manager.getRepository(MediaEntity).countBy({
        ownerType: owner.type,
        ownerId: owner.id,
        status: 'PENDING_UPLOAD',
      });
      if (open >= MAX_PENDING_PER_EVENT) {
        throw new AppException(
          ErrorCode.LIMIT_REACHED,
          HttpStatus.CONFLICT,
          'Too many unfinished uploads. Try again later.',
        );
      }
      await manager.insert(MediaEntity, {
        id,
        ownerType: owner.type,
        ownerId: owner.id,
        kind: dto.kind,
        status: 'PENDING_UPLOAD',
        folder,
        fileName,
        uploadedByType: 'USER',
        uploadedById: userId,
      });
    });
    const upload = this.imageKit.uploadToken(
      { fileName, folder, checks: '"file.size" <= "5mb"' },
      now,
    );
    return {
      mediaId: id,
      uploadUrl: IMAGEKIT_UPLOAD_URL,
      token: upload.token,
      fields: upload.fields,
      expire: upload.expire,
      maxBytes: COVER_MAX_BYTES,
    };
  }

  /** Event covers belong to the caller's event; photos to the caller. */
  private async ownerOf(
    userId: string,
    dto: CreateUploadDto,
  ): Promise<{ type: 'EVENT' | 'USER'; id: string }> {
    if (dto.kind === 'USER_PHOTO') {
      if (dto.ownerId !== userId) {
        throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
      }
      return { type: 'USER', id: userId };
    }
    const event = await this.events.findOneBy({
      id: dto.ownerId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) {
      throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
    }
    return { type: 'EVENT', id: event.id };
  }

  /**
   * Verifies the uploaded file with ImageKit (never trusting the app): it
   * must sit exactly at the reserved path, be private, an allowed image type
   * and 1 byte–5 MB. Otherwise the file is deleted (only when it is at the
   * reserved path) and the upload rejected with 422 MEDIA_INVALID.
   */
  async completeUpload(
    userId: string,
    mediaId: string,
    fileId: string,
    context: RequestContext,
  ): Promise<MediaEntity> {
    this.assertEnabled();
    const media = await this.media.findOneBy({
      id: mediaId,
      uploadedById: userId,
      deletedAt: IsNull(),
    });
    if (!media) {
      throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
    }
    if (media.status === 'READY' && media.imagekitFileId === fileId) {
      return media; // repeated completion (retry) is harmless
    }
    if (media.status !== 'PENDING_UPLOAD') throw notWaiting();

    const file = await this.fetch(() => this.imageKit.getFile(fileId));
    const reserved = `${media.folder}/${media.fileName}`;
    const problem = this.problemWith(file, reserved);
    if (problem || !file) {
      await this.reject(media, problem ?? 'NOT_FOUND', file, userId, context);
      throw invalid(problem ?? 'NOT_FOUND');
    }

    try {
      await this.dataSource.transaction(async (manager) => {
        // Conditional: two concurrent completions can't both succeed.
        const result = await manager.update(
          MediaEntity,
          { id: media.id, status: 'PENDING_UPLOAD' },
          {
            status: 'READY',
            imagekitFileId: file.fileId,
            filePath: file.filePath,
            contentType: file.mime,
            sizeBytes: file.size,
            width: file.width,
            height: file.height,
          },
        );
        if (!result.affected) throw notWaiting();
        await this.audit.record(manager, {
          actorType: 'USER',
          actorId: userId,
          action: 'MEDIA_UPLOADED',
          entityType: 'MEDIA',
          entityId: media.id,
          requestId: context.requestId,
          ip: context.ip,
          summary: { kind: media.kind, sizeBytes: file.size },
        });
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        // The same ImageKit file is already attached to another upload.
        throw invalid('WRONG_PATH');
      }
      throw error;
    }
    return this.media.findOneByOrFail({ id: media.id });
  }

  /**
   * Rejects uploads never completed within 24 h and removes their files
   * from the reserved path (hourly job). Returns how many were rejected.
   */
  async rejectAbandoned(now = new Date()): Promise<number> {
    const stale = await this.media.find({
      where: {
        status: 'PENDING_UPLOAD',
        createdAt: LessThan(new Date(now.getTime() - PENDING_UPLOAD_TTL_MS)),
      },
      take: CLEANUP_BATCH,
      order: { createdAt: 'ASC' },
    });
    for (const media of stale) {
      if (this.imageKit.enabled) {
        await this.deleteReserved(media);
      }
      await this.media.update(
        { id: media.id, status: 'PENDING_UPLOAD' },
        { status: 'REJECTED', rejectionReason: 'ABANDONED' },
      );
    }
    return stale.length;
  }

  private problemWith(
    file: ImageKitFile | null,
    reserved: string,
  ): Problem | null {
    if (!file) return 'NOT_FOUND';
    if (file.filePath !== reserved) return 'WRONG_PATH';
    if (!file.isPrivateFile) return 'NOT_PRIVATE';
    if (!file.mime || !(file.mime in IMAGE_TYPES)) return 'TYPE_NOT_ALLOWED';
    if (file.size < 1) return 'EMPTY';
    if (file.size > COVER_MAX_BYTES) return 'TOO_LARGE';
    return null;
  }

  /**
   * Marks the upload REJECTED first (only if still pending, so a concurrent
   * successful completion wins), then removes its file and audits.
   */
  private async reject(
    media: MediaEntity,
    problem: Problem,
    file: ImageKitFile | null,
    userId: string,
    context: RequestContext,
  ): Promise<void> {
    const rejected = await this.dataSource.transaction(async (manager) => {
      const result = await manager.update(
        MediaEntity,
        { id: media.id, status: 'PENDING_UPLOAD' },
        { status: 'REJECTED', rejectionReason: problem },
      );
      if (!result.affected) return false;
      await this.audit.record(manager, {
        actorType: 'USER',
        actorId: userId,
        action: 'MEDIA_REJECTED',
        entityType: 'MEDIA',
        entityId: media.id,
        requestId: context.requestId,
        ip: context.ip,
        summary: { kind: media.kind, reason: problem },
      });
      return true;
    });
    if (!rejected) throw notWaiting();
    // Never delete a file found elsewhere: it may be someone else's. The
    // reserved path holds only this upload (server-generated media id).
    const reserved = `${media.folder}/${media.fileName}`;
    if (file && file.filePath === reserved) {
      await this.imageKit
        .deleteFile(file.fileId)
        .catch((error) =>
          this.logger.warn(`ImageKit delete failed (${errorText(error)})`),
        );
    } else {
      // Search is eventually consistent: a just-uploaded file may not be
      // found yet; such leftovers are covered by GI-30.
      await this.deleteReserved(media);
    }
  }

  /** Best effort: deletes whatever is stored at the upload's reserved path. */
  private async deleteReserved(media: MediaEntity): Promise<void> {
    try {
      const file = await this.imageKit.findByPath(
        `${media.folder}/${media.fileName}`,
      );
      if (file) await this.imageKit.deleteFile(file.fileId);
    } catch (error) {
      this.logger.warn(`ImageKit clean-up failed (${errorText(error)})`);
    }
  }

  private async fetch<T>(call: () => Promise<T>): Promise<T> {
    try {
      return await call();
    } catch (error) {
      this.logger.warn(`ImageKit request failed (${errorText(error)})`);
      throw new AppException(
        ErrorCode.SERVICE_UNAVAILABLE,
        HttpStatus.SERVICE_UNAVAILABLE,
        'Photos are temporarily unavailable. Please try again.',
      );
    }
  }

  private assertEnabled(): void {
    if (!this.imageKit.enabled) {
      throw new AppException(
        ErrorCode.SERVICE_UNAVAILABLE,
        HttpStatus.SERVICE_UNAVAILABLE,
        'Photo uploads are not available right now.',
      );
    }
  }
}

function notWaiting(): AppException {
  return new AppException(
    ErrorCode.INVALID_STATE_TRANSITION,
    HttpStatus.CONFLICT,
    'This upload is no longer waiting for a file. Start a new upload.',
  );
}

function invalid(problem: Problem): AppException {
  const message =
    problem === 'TOO_LARGE'
      ? 'The photo is larger than 5 MB.'
      : problem === 'EMPTY'
        ? 'The photo is empty.'
        : problem === 'TYPE_NOT_ALLOWED'
          ? 'Only JPEG, PNG, WebP or HEIC photos can be used.'
          : 'The uploaded photo could not be verified. Please try again.';
  return new AppException(
    ErrorCode.MEDIA_INVALID,
    HttpStatus.UNPROCESSABLE_ENTITY,
    message,
    [{ field: 'fileId', code: problem, message: 'Upload rejected' }],
  );
}

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof QueryFailedError &&
    (error.driverError as { code?: string } | undefined)?.code === '23505'
  );
}

function errorText(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
