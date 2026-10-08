import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { DEFAULT_PAGE_LIMIT } from '../../common/pagination/cursor';
import { MONEY_AMOUNT_PATTERN, type MoneyJson } from '../../common/money/money';

/** Page size for discovery (spec item 3). */
export const MAX_LISTINGS_LIMIT = 50;

/** Omitted = relevance (search match first, then newest). */
export const LISTING_SORTS = [
  '-publishedAt',
  'startingPrice',
  '-startingPrice',
] as const;
export type ListingSort = (typeof LISTING_SORTS)[number] | 'relevance';

/** Trimmed; blank means "not given". */
const trimToUndefined = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || undefined : value;

const PRICE_MESSAGE =
  'must be a decimal string with exactly 2 decimals, e.g. "25000.00"';

export class ListListingsQuery {
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  /** Matches the listing's city or one of its service areas (O2). */
  @IsOptional()
  @Transform(trimToUndefined)
  @IsString()
  @Length(1, 80)
  city?: string;

  /** Listing title, vendor name or category name. */
  @IsOptional()
  @Transform(trimToUndefined)
  @IsString()
  @Length(1, 100)
  q?: string;

  @IsOptional()
  @Matches(MONEY_AMOUNT_PATTERN, {
    message: `minStartingPrice ${PRICE_MESSAGE}`,
  })
  minStartingPrice?: string;

  @IsOptional()
  @Matches(MONEY_AMOUNT_PATTERN, {
    message: `maxStartingPrice ${PRICE_MESSAGE}`,
  })
  maxStartingPrice?: string;

  @IsOptional()
  @IsIn(LISTING_SORTS)
  sort?: (typeof LISTING_SORTS)[number];

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_LISTINGS_LIMIT)
  limit: number = DEFAULT_PAGE_LIMIT;

  @IsOptional()
  @IsString()
  @Length(1, 512)
  cursor?: string;
}

/**
 * A listing card (spec item 3). The starting price is marketplace
 * information only — never a budget or agreed amount.
 */
export interface ListingCardDto {
  id: string;
  title: string;
  category: { id: string; name: string; slug: string };
  vendor: { id: string; businessName: string };
  city: string;
  serviceAreas: string[];
  startingPrice: MoneyJson;
  /** Average with one decimal (e.g. "4.5"), null until rated (M20). */
  rating: { average: string | null; count: number };
  /** Listing photos arrive in M28; until then the app shows the category icon. */
  coverImageUrl: string | null;
  publishedAt: string;
}
