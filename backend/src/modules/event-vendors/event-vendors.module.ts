import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEntity } from '../events/event.entity';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { ListingsModule } from '../listings/listings.module';
import { BookingAutoCompleteJob } from './booking-auto-complete.job';
import { BookingEntity } from './booking.entity';
import { EnquiryEntity } from './enquiry.entity';
import { PaymentNoteEntity } from './payment-note.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { QuotationEntity } from './quotation.entity';
import { EventVendorEntity } from './event-vendor.entity';
import { EventVendorsController } from './event-vendors.controller';
import { EventVendorsService } from './event-vendors.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      EventVendorEntity,
      EnquiryEntity,
      QuotationEntity,
      BookingEntity,
      PaymentNoteEntity,
      EventEntity,
    ]),
    IdempotencyModule,
    ListingsModule,
  ],
  controllers: [EventVendorsController, PaymentsController],
  providers: [EventVendorsService, PaymentsService, BookingAutoCompleteJob],
})
export class EventVendorsModule {}
