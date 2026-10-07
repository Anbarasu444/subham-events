import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  CreateChecklistItemDto,
  ReorderChecklistDto,
  UpdateChecklistItemDto,
  type ChecklistDto,
  type ChecklistItemDto,
} from './checklist.dto';
import { ChecklistService, type ChecklistAction } from './checklist.service';

/** Unknown or malformed ids are reported like other users' data: 404. */
const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

// Per IP; ticking items quickly is normal, so the bucket is generous.
const WRITE_LIMIT = { name: 'checklist-write', limit: 300, windowSeconds: 60 };

/** An event's checklist (M9, api-contracts.md Part B). */
@Controller('events/:eventId/checklist')
export class ChecklistController {
  constructor(
    private readonly checklist: ChecklistService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  get(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<ChecklistDto> {
    return this.checklist.get(user.userId, eventId);
  }

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: CreateChecklistItemDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ChecklistItemDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/checklist`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.checklist.create(
          manager,
          user.userId,
          eventId,
          dto,
          contextOf(req),
        ),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Put('order')
  @RateLimit(WRITE_LIMIT)
  reorder(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: ReorderChecklistDto,
    @Req() req: Request,
  ): Promise<ChecklistDto> {
    return this.dataSource.transaction((manager) =>
      this.checklist.reorder(
        manager,
        user.userId,
        eventId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Patch(':itemId')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('itemId', Id()) itemId: string,
    @Body() dto: UpdateChecklistItemDto,
    @Req() req: Request,
  ): Promise<ChecklistItemDto> {
    return this.dataSource.transaction((manager) =>
      this.checklist.update(
        manager,
        user.userId,
        eventId,
        itemId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Post(':itemId/complete')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  complete(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('itemId', Id()) itemId: string,
    @Req() req: Request,
  ): Promise<ChecklistItemDto> {
    return this.transition(user, eventId, itemId, 'complete', req);
  }

  @Post(':itemId/reopen')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  reopen(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('itemId', Id()) itemId: string,
    @Req() req: Request,
  ): Promise<ChecklistItemDto> {
    return this.transition(user, eventId, itemId, 'reopen', req);
  }

  @Delete(':itemId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('itemId', Id()) itemId: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.checklist.remove(
        manager,
        user.userId,
        eventId,
        itemId,
        contextOf(req),
      ),
    );
  }

  private transition(
    user: RequestUser,
    eventId: string,
    itemId: string,
    action: ChecklistAction,
    req: Request,
  ): Promise<ChecklistItemDto> {
    return this.dataSource.transaction((manager) =>
      this.checklist.transition(
        manager,
        user.userId,
        eventId,
        itemId,
        action,
        contextOf(req),
      ),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
