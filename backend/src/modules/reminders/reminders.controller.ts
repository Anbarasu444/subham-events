import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
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
  CreateReminderDto,
  MyRemindersQuery,
  UpdateReminderDto,
  type EventRemindersDto,
  type ReminderDto,
} from './reminders.dto';
import { RemindersService } from './reminders.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'reminders-write', limit: 120, windowSeconds: 60 };

/** An event's reminders (M17, api-contracts.md Part B). */
@Controller('events/:eventId/reminders')
export class EventRemindersController {
  constructor(
    private readonly reminders: RemindersService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  list(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<EventRemindersDto> {
    return this.reminders.list(user.userId, eventId);
  }

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: CreateReminderDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ReminderDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/reminders`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.reminders.create(
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

  @Patch(':reminderId')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('reminderId', Id()) reminderId: string,
    @Body() dto: UpdateReminderDto,
    @Req() req: Request,
  ): Promise<ReminderDto> {
    return this.dataSource.transaction((manager) =>
      this.reminders.update(
        manager,
        user.userId,
        eventId,
        reminderId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Post(':reminderId/cancel')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  cancel(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('reminderId', Id()) reminderId: string,
    @Req() req: Request,
  ): Promise<ReminderDto> {
    return this.dataSource.transaction((manager) =>
      this.reminders.cancel(
        manager,
        user.userId,
        eventId,
        reminderId,
        contextOf(req),
      ),
    );
  }

  /** Dismisses the in-app "due" banner. */
  @Post(':reminderId/seen')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async seen(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('reminderId', Id()) reminderId: string,
  ): Promise<void> {
    await this.reminders.markSeen(user.userId, eventId, reminderId);
  }
}

/** The user's reminders across events (Home, Menu → Schedule). */
@Controller('me/reminders')
export class MyRemindersController {
  constructor(private readonly reminders: RemindersService) {}

  @Get()
  mine(
    @CurrentUser() user: RequestUser,
    @Query() query: MyRemindersQuery,
  ): Promise<ReminderDto[]> {
    return this.reminders.mine(user.userId, query.scope, query.limit);
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
