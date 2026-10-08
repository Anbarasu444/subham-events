import {
  Controller,
  Get,
  Header,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Query,
} from '@nestjs/common';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { OptionalAuth, Public } from '../auth/auth.decorators';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  ListListingsQuery,
  type ListingCardDto,
  type ListingDetailDto,
  type RelatedListingsDto,
} from './listings.dto';
import { ListingsService } from './listings.service';

const READ_LIMIT = { name: 'listings-read', limit: 120, windowSeconds: 60 };

/** Malformed ids are reported like unknown ones: 404. */
const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

/** Public vendor discovery (M12, api-contracts.md Part B). */
@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  /** Public; `saved=true` needs a signed-in caller. */
  @Get()
  @OptionalAuth()
  @RateLimit(READ_LIMIT)
  async search(
    @Query() query: ListListingsQuery,
    @CurrentUser() user: RequestUser | undefined,
  ): Promise<Enveloped<ListingCardDto[]>> {
    const { items, page } = await this.listings.search(query, user?.userId);
    return new Enveloped(items, { page });
  }

  @Get('cities')
  @Public()
  @RateLimit(READ_LIMIT)
  @Header('Cache-Control', 'public, max-age=300')
  cities(): Promise<string[]> {
    return this.listings.cities();
  }

  /** Guests see no vendor contact details (A10); signed-in users do. */
  @Get(':id')
  @OptionalAuth()
  @RateLimit(READ_LIMIT)
  detail(
    @Param('id', Id()) id: string,
    @CurrentUser() user: RequestUser | undefined,
  ): Promise<ListingDetailDto> {
    return this.listings.detail(id, user !== undefined);
  }

  @Get(':id/related')
  @Public()
  @RateLimit(READ_LIMIT)
  related(@Param('id', Id()) id: string): Promise<RelatedListingsDto> {
    return this.listings.related(id);
  }
}
