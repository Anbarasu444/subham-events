import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RateLimitCounterEntity } from './rate-limit-counter.entity';
import { RateLimitGuard } from './rate-limit.guard';
import { PostgresRateLimitStore, RateLimitStore } from './rate-limit.store';

@Module({
  imports: [TypeOrmModule.forFeature([RateLimitCounterEntity])],
  providers: [
    { provide: RateLimitStore, useClass: PostgresRateLimitStore },
    RateLimitGuard,
  ],
  exports: [RateLimitStore, RateLimitGuard],
})
export class RateLimitModule {}
