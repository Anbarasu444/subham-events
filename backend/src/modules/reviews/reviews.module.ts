import { Module } from '@nestjs/common';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import {
  BookingReviewController,
  ListingReviewsController,
  MyReviewsController,
} from './reviews.controller';
import { ReviewReminderJob } from './review-reminder.job';
import { ReviewsService } from './reviews.service';

@Module({
  imports: [IdempotencyModule],
  controllers: [
    BookingReviewController,
    MyReviewsController,
    ListingReviewsController,
  ],
  providers: [ReviewsService, ReviewReminderJob],
})
export class ReviewsModule {}
