import { Body, Controller, Delete, Get, Patch, Put, Req } from '@nestjs/common';
import type { Request } from 'express';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { SetPhotoDto, UpdateMeDto, type MeDto } from './me.dto';
import { ProfileService } from './profile.service';

const WRITE_LIMIT = { name: 'profile-write', limit: 30, windowSeconds: 60 };

@Controller('me')
export class MeController {
  constructor(private readonly profile: ProfileService) {}

  @Get()
  me(@CurrentUser() current: RequestUser): Promise<MeDto> {
    return this.profile.me(current.userId);
  }

  /** Name only: phone and email come from sign-in (M21). */
  @Patch()
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() current: RequestUser,
    @Body() dto: UpdateMeDto,
    @Req() req: Request,
  ): Promise<MeDto> {
    return this.profile.updateName(
      current.userId,
      dto.displayName,
      contextOf(req),
    );
  }

  @Put('photo')
  @RateLimit(WRITE_LIMIT)
  setPhoto(
    @CurrentUser() current: RequestUser,
    @Body() dto: SetPhotoDto,
    @Req() req: Request,
  ): Promise<MeDto> {
    return this.profile.setPhoto(current.userId, dto.mediaId, contextOf(req));
  }

  @Delete('photo')
  @RateLimit(WRITE_LIMIT)
  removePhoto(
    @CurrentUser() current: RequestUser,
    @Req() req: Request,
  ): Promise<MeDto> {
    return this.profile.removePhoto(current.userId, contextOf(req));
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
