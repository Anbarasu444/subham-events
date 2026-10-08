import { Type } from 'class-transformer';
import { ValidateNested } from 'class-validator';
import { MoneyDto } from '../../common/money/money.dto';
import type { MoneyJson } from '../../common/money/money';

export class SetAllocationDto {
  @ValidateNested()
  @Type(() => MoneyDto)
  planned: MoneyDto;
}

export interface BudgetCategoryDto {
  categoryId: string;
  name: string;
  /** The category is no longer offered; listed only because it has a plan. */
  isArchived: boolean;
  /** Null when nothing is planned for this category. */
  planned: MoneyJson | null;
  /** Agreed amounts of confirmed bookings (M15); zero until then. */
  committed: MoneyJson;
  /** The user's payment notes (M16); zero until then. */
  paid: MoneyJson;
  /** The user's own expenses with this category. */
  expenses: MoneyJson;
}

/**
 * Event budget (domain-model.md §7). All figures are computed on the server
 * with exact decimals; listing starting prices never appear here.
 */
export interface BudgetDto {
  eventId: string;
  /** False when the event is not PLANNING (read-only, like the checklist). */
  isEditable: boolean;
  totalBudget: MoneyJson | null;
  planned: MoneyJson;
  /** Total − planned; null without a total budget. Negative = over-planned. */
  unplanned: MoneyJson | null;
  isOverPlanned: boolean;
  committed: MoneyJson;
  paid: MoneyJson;
  /** Paid to vendors whose booking was later cancelled (part of `paid`, A11). */
  paidToCancelled: MoneyJson;
  /** What is still to pay on active bookings (Σ positive balances). */
  outstanding: MoneyJson;
  /** Sum of the user's own expenses (with or without a category). */
  expenses: MoneyJson;
  /** Paid + expenses. */
  spent: MoneyJson;
  /** Total − committed − expenses; null without a total. Negative = over. */
  remaining: MoneyJson | null;
  categories: BudgetCategoryDto[];
}
