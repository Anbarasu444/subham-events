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
  AddEventVendorDto,
  CancelBookingDto,
  CreateEnquiryDto,
  UpdateEventVendorDto,
  type EventVendorDto,
  type EventVendorListDto,
} from './event-vendors.dto';
import { EventVendorsService } from './event-vendors.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = {
  name: 'event-vendors-write',
  limit: 120,
  windowSeconds: 60,
};
// Enquiries notify vendors: a tighter bucket against spam.
const ENQUIRY_LIMIT = { name: 'enquiries-write', limit: 20, windowSeconds: 60 };

/** An event's vendors and enquiries (M14, api-contracts.md Part B). */
@Controller('events/:eventId/vendors')
export class EventVendorsController {
  constructor(
    private readonly vendors: EventVendorsService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  list(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<EventVendorListDto> {
    return this.vendors.list(user.userId, eventId);
  }

  /** 201 when added, 200 when the listing was already on the event. */
  @Post()
  @RateLimit(WRITE_LIMIT)
  async add(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: AddEventVendorDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<EventVendorDto> {
    const { vendor, created } = await this.dataSource.transaction((manager) =>
      this.vendors.add(
        manager,
        user.userId,
        eventId,
        dto.listingId,
        contextOf(req),
      ),
    );
    res.status(created ? HttpStatus.CREATED : HttpStatus.OK);
    return vendor;
  }

  @Patch(':eventVendorId')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Body() dto: UpdateEventVendorDto,
    @Req() req: Request,
  ): Promise<EventVendorDto> {
    return this.dataSource.transaction((manager) =>
      this.vendors.update(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Delete(':eventVendorId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.vendors.remove(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        contextOf(req),
      ),
    );
  }

  /** Idempotency-Key required (a retry never sends a second enquiry). */
  @Post(':eventVendorId/enquiries')
  @RateLimit(ENQUIRY_LIMIT)
  async enquire(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Body() dto: CreateEnquiryDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<EventVendorDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/vendors/${eventVendorId}/enquiries`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.vendors.enquire(
          manager,
          user.userId,
          eventId,
          eventVendorId,
          dto,
          contextOf(req),
        ),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Post(':eventVendorId/enquiries/:enquiryId/close')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  close(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Param('enquiryId', Id()) enquiryId: string,
    @Req() req: Request,
  ): Promise<EventVendorDto> {
    return this.dataSource.transaction((manager) =>
      this.vendors.closeEnquiry(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        enquiryId,
        contextOf(req),
      ),
    );
  }

  /** Idempotency-Key required: a double tap never books twice. */
  @Post(':eventVendorId/quotations/:quotationId/accept')
  @RateLimit(WRITE_LIMIT)
  async accept(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Param('quotationId', Id()) quotationId: string,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<EventVendorDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/vendors/${eventVendorId}/quotations/${quotationId}/accept`,
        body: {},
      },
      HttpStatus.OK,
      (manager) =>
        this.vendors.acceptQuotation(
          manager,
          user.userId,
          eventId,
          eventVendorId,
          quotationId,
          contextOf(req),
        ),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Post(':eventVendorId/quotations/:quotationId/reject')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  reject(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Param('quotationId', Id()) quotationId: string,
    @Req() req: Request,
  ): Promise<EventVendorDto> {
    return this.dataSource.transaction((manager) =>
      this.vendors.rejectQuotation(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        quotationId,
        contextOf(req),
      ),
    );
  }

  @Post(':eventVendorId/booking/cancel')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  cancelBooking(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Body() dto: CancelBookingDto,
    @Req() req: Request,
  ): Promise<EventVendorDto> {
    return this.dataSource.transaction((manager) =>
      this.vendors.cancelBooking(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        dto.reason,
        contextOf(req),
      ),
    );
  }

  @Post(':eventVendorId/booking/complete')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  completeBooking(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('eventVendorId', Id()) eventVendorId: string,
    @Req() req: Request,
  ): Promise<EventVendorDto> {
    return this.dataSource.transaction((manager) =>
      this.vendors.completeBooking(
        manager,
        user.userId,
        eventId,
        eventVendorId,
        contextOf(req),
      ),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
