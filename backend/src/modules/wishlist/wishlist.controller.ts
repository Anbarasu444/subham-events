import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { DEFAULT_PAGE_LIMIT } from '../../common/pagination/cursor';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { WishlistService, type WishlistItemDto } from './wishlist.service';

class ListWishlistQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = DEFAULT_PAGE_LIMIT;

  @IsOptional()
  @IsString()
  @Length(1, 512)
  cursor?: string;
}

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'wishlist-write', limit: 120, windowSeconds: 60 };

/** The signed-in user's saved vendors (M14, api-contracts.md Part B). */
@Controller('me/wishlist')
export class WishlistController {
  constructor(private readonly wishlist: WishlistService) {}

  @Get()
  async list(
    @CurrentUser() user: RequestUser,
    @Query() query: ListWishlistQuery,
  ): Promise<Enveloped<WishlistItemDto[]>> {
    const { items, page } = await this.wishlist.list(
      user.userId,
      query.limit,
      query.cursor,
    );
    return new Enveloped(items, { page });
  }

  @Get('ids')
  ids(@CurrentUser() user: RequestUser): Promise<string[]> {
    return this.wishlist.ids(user.userId);
  }

  @Put(':listingId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async save(
    @CurrentUser() user: RequestUser,
    @Param('listingId', Id()) listingId: string,
  ): Promise<void> {
    await this.wishlist.save(user.userId, listingId);
  }

  @Delete(':listingId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('listingId', Id()) listingId: string,
  ): Promise<void> {
    await this.wishlist.remove(user.userId, listingId);
  }
}
