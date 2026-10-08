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
  CreatePaymentDto,
  UpdatePaymentDto,
  type PaymentDto,
  type PaymentListDto,
} from './payments.dto';
import { PaymentsService } from './payments.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'payments-write', limit: 120, windowSeconds: 60 };

/** Private payment notes per booking (M16, api-contracts.md Part B). */
@Controller('events/:eventId/bookings/:bookingId/payments')
export class PaymentsController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  list(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('bookingId', Id()) bookingId: string,
  ): Promise<PaymentListDto> {
    return this.payments.list(user.userId, eventId, bookingId);
  }

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('bookingId', Id()) bookingId: string,
    @Body() dto: CreatePaymentDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<PaymentDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/bookings/${bookingId}/payments`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.payments.create(
          manager,
          user.userId,
          eventId,
          bookingId,
          dto,
          contextOf(req),
        ),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Patch(':paymentId')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('bookingId', Id()) bookingId: string,
    @Param('paymentId', Id()) paymentId: string,
    @Body() dto: UpdatePaymentDto,
    @Req() req: Request,
  ): Promise<PaymentDto> {
    return this.dataSource.transaction((manager) =>
      this.payments.update(
        manager,
        user.userId,
        eventId,
        bookingId,
        paymentId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Delete(':paymentId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('bookingId', Id()) bookingId: string,
    @Param('paymentId', Id()) paymentId: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.payments.remove(
        manager,
        user.userId,
        eventId,
        bookingId,
        paymentId,
        contextOf(req),
      ),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
