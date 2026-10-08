import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChecklistItemEntity } from '../checklist/checklist-item.entity';
import { EventEntity } from '../events/event.entity';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { ReminderEntity } from './reminder.entity';
import { ReminderJobs } from './reminder-jobs';
import {
  EventRemindersController,
  MyRemindersController,
} from './reminders.controller';
import { RemindersService } from './reminders.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ReminderEntity,
      ChecklistItemEntity,
      EventEntity,
    ]),
    IdempotencyModule,
  ],
  controllers: [EventRemindersController, MyRemindersController],
  providers: [RemindersService, ReminderJobs],
})
export class RemindersModule {}
