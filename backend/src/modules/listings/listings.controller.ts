import { Controller, Get, Header, Query } from '@nestjs/common';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { Public } from '../auth/auth.decorators';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { ListListingsQuery, type ListingCardDto } from './listings.dto';
import { ListingsService } from './listings.service';

const READ_LIMIT = { name: 'listings-read', limit: 120, windowSeconds: 60 };

/** Public vendor discovery (M12, api-contracts.md Part B). */
@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get()
  @Public()
  @RateLimit(READ_LIMIT)
  async search(
    @Query() query: ListListingsQuery,
  ): Promise<Enveloped<ListingCardDto[]>> {
    const { items, page } = await this.listings.search(query);
    return new Enveloped(items, { page });
  }

  @Get('cities')
  @Public()
  @RateLimit(READ_LIMIT)
  @Header('Cache-Control', 'public, max-age=300')
  cities(): Promise<string[]> {
    return this.listings.cities();
  }
}
