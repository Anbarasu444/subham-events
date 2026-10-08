import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditModule } from '../audit/audit.module';
import { ChecklistModule } from '../checklist/checklist.module';
import { MediaModule } from '../media/media.module';
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
    ChecklistModule,
    MediaModule,
  ],
  controllers: [EventsController],
  providers: [EventsService, EventAutoCompleteJob],
})
export class EventsModule {}
