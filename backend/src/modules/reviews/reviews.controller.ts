import {
  Body,
  Controller,
  Get,
  Headers,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { getRequestId } from '../../common/logging/request-id';
import { Public } from '../auth/auth.decorators';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  CreateReviewDto,
  ListReviewsQuery,
  type PublicReviewDto,
  type RatingSummaryDto,
  type ReviewDto,
} from './reviews.dto';
import { ReviewsService } from './reviews.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'reviews-write', limit: 20, windowSeconds: 60 };
const READ_LIMIT = { name: 'listings-read', limit: 120, windowSeconds: 60 };

/** Write a review for a completed booking (M20, A5, A12). */
@Controller('events/:eventId/bookings/:bookingId/review')
export class BookingReviewController {
  constructor(
    private readonly reviews: ReviewsService,
    private readonly idempotency: IdempotencyService,
  ) {}

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('bookingId', Id()) bookingId: string,
    @Body() dto: CreateReviewDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ReviewDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/bookings/${bookingId}/review`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.reviews.create(
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
}

/** The caller's own reviews. */
@Controller('me/reviews')
export class MyReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get()
  async mine(
    @CurrentUser() user: RequestUser,
    @Query() query: ListReviewsQuery,
  ): Promise<Enveloped<ReviewDto[]>> {
    const { items, page } = await this.reviews.mine(
      user.userId,
      query.limit,
      query.cursor,
    );
    return new Enveloped(items, { page });
  }
}

/** Public ratings and approved comments of a listing. */
@Controller('listings/:id')
export class ListingReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get('rating')
  @Public()
  @RateLimit(READ_LIMIT)
  summary(@Param('id', Id()) id: string): Promise<RatingSummaryDto> {
    return this.reviews.summary(id);
  }

  @Get('reviews')
  @Public()
  @RateLimit(READ_LIMIT)
  async list(
    @Param('id', Id()) id: string,
    @Query() query: ListReviewsQuery,
  ): Promise<Enveloped<PublicReviewDto[]>> {
    const { items, page } = await this.reviews.publicList(
      id,
      query.limit,
      query.cursor,
    );
    return new Enveloped(items, { page });
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
