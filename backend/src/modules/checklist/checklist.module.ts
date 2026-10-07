import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEntity } from '../events/event.entity';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { ChecklistItemEntity } from './checklist-item.entity';
import { ChecklistSummaryService } from './checklist-summary.service';
import { ChecklistController } from './checklist.controller';
import { ChecklistService } from './checklist.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([ChecklistItemEntity, EventEntity]),
    IdempotencyModule,
  ],
  controllers: [ChecklistController],
  providers: [ChecklistService, ChecklistSummaryService],
  exports: [ChecklistSummaryService],
})
export class ChecklistModule {}
