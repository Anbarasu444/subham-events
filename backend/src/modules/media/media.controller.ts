import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  CompleteUploadDto,
  CreateUploadDto,
  type UploadIntentDto,
} from './media.dto';
import { MediaService } from './media.service';

const UPLOAD_LIMIT = { name: 'media-upload', limit: 10, windowSeconds: 60 };

/** Media uploads (M10: event cover photos). */
@Controller('media/uploads')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post()
  @RateLimit(UPLOAD_LIMIT)
  create(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateUploadDto,
  ): Promise<UploadIntentDto> {
    return this.media.createUpload(user.userId, dto);
  }

  @Post(':mediaId/complete')
  @HttpCode(HttpStatus.OK)
  @RateLimit(UPLOAD_LIMIT)
  async complete(
    @CurrentUser() user: RequestUser,
    @Param(
      'mediaId',
      new ParseUUIDPipe({
        exceptionFactory: () =>
          new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
      }),
    )
    mediaId: string,
    @Body() dto: CompleteUploadDto,
    @Req() req: Request,
  ): Promise<{ mediaId: string; status: string }> {
    const media = await this.media.completeUpload(
      user.userId,
      mediaId,
      dto.fileId,
      {
        requestId: getRequestId(req),
        ip: req.ip,
      },
    );
    return { mediaId: media.id, status: media.status };
  }
}
