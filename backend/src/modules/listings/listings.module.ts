import { Module } from '@nestjs/common';
import { ListingsController } from './listings.controller';
import { ListingsRepository } from './listings.repository';
import { ListingsService } from './listings.service';

@Module({
  controllers: [ListingsController],
  providers: [ListingsService, ListingsRepository],
})
export class ListingsModule {}
