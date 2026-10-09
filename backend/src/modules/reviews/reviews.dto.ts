import { Transform, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';

export type CommentStatus =
  'NONE' | 'PENDING_MODERATION' | 'APPROVED' | 'REJECTED' | 'HIDDEN';

const trimToNull = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const t = value.trim();
  return t.length === 0 ? undefined : t;
};

export class CreateReviewDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @Transform(trimToNull)
  @IsString()
  @Length(1, 1000)
  comment?: string;
}

export class ListReviewsQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  @Length(1, 512)
  cursor?: string;
}

/** The author's own view of a review (comment shown in any state). */
export interface ReviewDto {
  id: string;
  bookingId: string;
  listing: { id: string; title: string };
  rating: number;
  comment: string | null;
  commentStatus: CommentStatus;
  createdAt: string;
}

/** Public: approved comments only, reviewer as "Asha K." (answer 4). */
export interface PublicReviewDto {
  id: string;
  rating: number;
  comment: string;
  reviewerName: string;
  createdAt: string;
}

export interface RatingSummaryDto {
  /** One decimal ("4.5"), null without ratings. */
  average: string | null;
  count: number;
  /** Five entries, 5 stars first. */
  stars: { stars: number; count: number }[];
}
