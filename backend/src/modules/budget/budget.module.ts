import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VendorCategoryEntity } from '../categories/vendor-category.entity';
import { EventEntity } from '../events/event.entity';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { BudgetAllocationEntity } from './budget-allocation.entity';
import { BudgetController } from './budget.controller';
import { BudgetService } from './budget.service';
import { EventExpenseEntity } from './event-expense.entity';
import { ExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BudgetAllocationEntity,
      EventExpenseEntity,
      VendorCategoryEntity,
      EventEntity,
    ]),
    IdempotencyModule,
  ],
  controllers: [BudgetController, ExpensesController],
  providers: [BudgetService, ExpensesService],
})
export class BudgetModule {}
