import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEntity } from '../events/event.entity';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { ListingsModule } from '../listings/listings.module';
import { EnquiryEntity } from './enquiry.entity';
import { EventVendorEntity } from './event-vendor.entity';
import { EventVendorsController } from './event-vendors.controller';
import { EventVendorsService } from './event-vendors.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([EventVendorEntity, EnquiryEntity, EventEntity]),
    IdempotencyModule,
    ListingsModule,
  ],
  controllers: [EventVendorsController],
  providers: [EventVendorsService],
})
export class EventVendorsModule {}
