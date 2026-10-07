import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { EventAutoCompleteJob } from './event-auto-complete.job';
import { EventEntity } from './event.entity';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([EventEntity]),
    AuditModule,
    IdempotencyModule,
  ],
  controllers: [EventsController],
  providers: [EventsService, EventAutoCompleteJob],
})
export class EventsModule {}
