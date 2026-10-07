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
  Query,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import type { EventAction } from './event-rules';
import {
  CreateEventDto,
  ListEventsQuery,
  UpdateEventDto,
  type EventDto,
} from './events.dto';
import { EventsService, type RequestContext } from './events.service';

/** Unknown or malformed ids are reported like other users' events: 404. */
const EventId = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

// Per IP; generous because mobile carrier NAT puts many users behind one IP.
const WRITE_LIMIT = { name: 'events-write', limit: 120, windowSeconds: 60 };

/** The signed-in user's own events (M8, api-contracts.md Part B). */
@Controller('events')
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateEventDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<EventDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: 'POST /events',
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.events.create(manager, user.userId, dto, contextOf(req)),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Get()
  async list(
    @CurrentUser() user: RequestUser,
    @Query() query: ListEventsQuery,
  ): Promise<Enveloped<EventDto[]>> {
    const { items, page } = await this.events.list(user.userId, query);
    return new Enveloped(items, { page });
  }

  @Get(':id')
  get(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
  ): Promise<EventDto> {
    return this.events.get(user.userId, id);
  }

  @Patch(':id')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
    @Body() dto: UpdateEventDto,
    @Req() req: Request,
  ): Promise<EventDto> {
    return this.dataSource.transaction((manager) =>
      this.events.update(manager, user.userId, id, dto, contextOf(req)),
    );
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  cancel(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
    @Req() req: Request,
  ): Promise<EventDto> {
    return this.transition(user, id, 'cancel', req);
  }

  @Post(':id/reopen')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  reopen(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
    @Req() req: Request,
  ): Promise<EventDto> {
    return this.transition(user, id, 'reopen', req);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  complete(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
    @Req() req: Request,
  ): Promise<EventDto> {
    return this.transition(user, id, 'complete', req);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('id', EventId()) id: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.events.remove(manager, user.userId, id, contextOf(req)),
    );
  }

  private transition(
    user: RequestUser,
    id: string,
    action: EventAction,
    req: Request,
  ): Promise<EventDto> {
    return this.dataSource.transaction((manager) =>
      this.events.transition(manager, user.userId, id, action, contextOf(req)),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
