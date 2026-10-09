import { HttpStatus, Injectable } from '@nestjs/common';
import { DataSource, IsNull, type EntityManager } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { AuditService } from '../audit/audit.service';
import type { RequestContext } from '../events/events.service';
import { CoverUrlService } from '../media/cover-url.service';
import { MediaEntity } from '../media/media.entity';
import { UserEntity } from './entities/user.entity';
import { toMeDto, type MeDto } from './me.dto';
import { UsersService } from './users.service';

/** The user's own profile: name and photo (M21). */
@Injectable()
export class ProfileService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly users: UsersService,
    private readonly covers: CoverUrlService,
    private readonly audit: AuditService,
  ) {}

  async me(userId: string, manager?: EntityManager): Promise<MeDto> {
    const user = manager
      ? await manager
          .getRepository(UserEntity)
          .findOne({ where: { id: userId }, relations: { roles: true } })
      : await this.users.findById(userId);
    if (!user) {
      throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
    }
    return this.toDto(user, manager);
  }

  /** MeDto with the photo's signed URLs. */
  async toDto(user: UserEntity, manager?: EntityManager): Promise<MeDto> {
    const photos = await this.covers.forMedia(
      [user.photoMediaId],
      new Date(),
      manager,
    );
    return toMeDto(
      user,
      user.photoMediaId ? (photos.get(user.photoMediaId) ?? null) : null,
    );
  }

  async updateName(
    userId: string,
    displayName: string,
    context: RequestContext,
  ): Promise<MeDto> {
    return this.dataSource.transaction(async (manager) => {
      const user = await this.lock(manager, userId);
      if (user.displayName !== displayName) {
        user.displayName = displayName;
        await manager.getRepository(UserEntity).save(user);
        await this.record(manager, userId, 'PROFILE_UPDATED', context, {
          fields: ['displayName'],
        });
      }
      return this.me(userId, manager);
    });
  }

  async setPhoto(
    userId: string,
    mediaId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<MeDto> {
    return this.dataSource.transaction(async (manager) => {
      const user = await this.lock(manager, userId);
      const media = await manager.getRepository(MediaEntity).findOneBy({
        id: mediaId,
        ownerType: 'USER',
        ownerId: userId,
        kind: 'USER_PHOTO',
        uploadedById: userId,
        deletedAt: IsNull(),
      });
      if (!media || media.status !== 'READY') {
        throw new AppException(
          ErrorCode.MEDIA_INVALID,
          HttpStatus.UNPROCESSABLE_ENTITY,
          'This photo is not ready to be used.',
          [{ field: 'mediaId', code: 'MEDIA_NOT_READY', message: 'Not ready' }],
        );
      }
      if (user.photoMediaId !== mediaId) {
        const previous = user.photoMediaId;
        user.photoMediaId = mediaId;
        await manager.getRepository(UserEntity).save(user);
        if (previous) {
          await manager.update(MediaEntity, previous, { deletedAt: now });
        }
        await this.record(manager, userId, 'PROFILE_PHOTO_SET', context, {
          mediaId,
          replaced: previous,
        });
      }
      return this.me(userId, manager);
    });
  }

  async removePhoto(
    userId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<MeDto> {
    return this.dataSource.transaction(async (manager) => {
      const user = await this.lock(manager, userId);
      const previous = user.photoMediaId;
      if (previous) {
        user.photoMediaId = null;
        await manager.getRepository(UserEntity).save(user);
        await manager.update(MediaEntity, previous, { deletedAt: now });
        await this.record(manager, userId, 'PROFILE_PHOTO_REMOVED', context, {
          mediaId: previous,
        });
      }
      return this.me(userId, manager);
    });
  }

  private async lock(
    manager: EntityManager,
    userId: string,
  ): Promise<UserEntity> {
    const user = await manager
      .getRepository(UserEntity)
      .createQueryBuilder('u')
      .setLock('pessimistic_write')
      .where('u.id = :userId', { userId })
      .getOne();
    if (!user) {
      throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
    }
    return user;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    // Field names only — never the name itself.
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'USER',
      entityId: userId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}
