import type { EntityManager, Repository } from 'typeorm';
import type { AuditService } from '../audit/audit.service';
import { VendorCategoryEntity } from '../categories/vendor-category.entity';
import type { EventEntity } from '../events/event.entity';
import { BudgetAllocationEntity } from './budget-allocation.entity';
import { BudgetService } from './budget.service';
import { EventExpenseEntity } from './event-expense.entity';

const categories = [
  { id: 'c1', name: 'Venue', status: 'PUBLISHED', sortOrder: 10 },
  { id: 'c2', name: 'Catering', status: 'PUBLISHED', sortOrder: 20 },
] as VendorCategoryEntity[];
const archived = {
  id: 'c9',
  name: 'Fireworks',
  status: 'ARCHIVED',
  sortOrder: 90,
} as VendorCategoryEntity;

function serviceWith(
  event: Partial<EventEntity>,
  allocations: { categoryId: string; plannedAmount: string }[],
  expenses: { categoryId: string | null; amount: string }[] = [],
  bookings: {
    category_id: string;
    agreed_amount: string;
    status?: string;
    paid?: string;
  }[] = [],
): BudgetService {
  const rows = allocations.map((a) => ({ ...a, currency: 'INR' }));
  const expenseRows = expenses.map((e) => ({ ...e, currency: 'INR' }));
  const manager = {
    query: () =>
      Promise.resolve(
        bookings.map((b) => ({
          status: 'CONFIRMED',
          paid: '0.00',
          ...b,
          currency: 'INR',
        })),
      ),
    getRepository: (entity: unknown) =>
      entity === VendorCategoryEntity
        ? {
            find: () => Promise.resolve(categories),
            findBy: () => Promise.resolve([archived]),
          }
        : entity === BudgetAllocationEntity
          ? { findBy: () => Promise.resolve(rows) }
          : entity === EventExpenseEntity
            ? { findBy: () => Promise.resolve(expenseRows) }
            : {},
  } as unknown as EntityManager;
  const events = {
    findOneBy: () =>
      Promise.resolve({
        id: 'e1',
        status: 'PLANNING',
        currency: 'INR',
        totalBudgetAmount: null,
        ...event,
      }),
    manager,
  } as unknown as Repository<EventEntity>;
  return new BudgetService(events, {} as AuditService);
}

describe('BudgetService figures', () => {
  it('adds payments to paid and spent, separates cancelled ones (A11)', async () => {
    const budget = await serviceWith(
      { totalBudgetAmount: '100000.00' },
      [],
      [{ categoryId: null, amount: '100.00' }],
      [
        { category_id: 'c1', agreed_amount: '40000.00', paid: '15000.50' },
        { category_id: 'c1', agreed_amount: '5000.00', paid: '6000.00' },
        {
          category_id: 'c2',
          agreed_amount: '9000.00',
          paid: '2000.00',
          status: 'CANCELLED',
        },
      ],
    ).get('u1', 'e1');
    expect(budget.paid.amount).toBe('23000.50');
    expect(budget.paidToCancelled.amount).toBe('2000.00');
    expect(budget.spent.amount).toBe('23100.50');
    expect(budget.committed.amount).toBe('45000.00');
    // Overpaid bookings do not reduce what is owed elsewhere.
    expect(budget.outstanding.amount).toBe('24999.50');
    expect(
      budget.categories.find((c) => c.categoryId === 'c2')!.paid.amount,
    ).toBe('2000.00');
  });

  it('commits confirmed bookings and leaves the rest as remaining', async () => {
    const budget = await serviceWith(
      { totalBudgetAmount: '100000.00' },
      [],
      [{ categoryId: null, amount: '0.10' }],
      [
        { category_id: 'c1', agreed_amount: '40000.00' },
        { category_id: 'c1', agreed_amount: '9999.95' },
      ],
    ).get('u1', 'e1');
    expect(budget.committed).toEqual({ amount: '49999.95', currency: 'INR' });
    expect(budget.remaining).toEqual({ amount: '49999.95', currency: 'INR' });
    expect(
      budget.categories.find((c) => c.categoryId === 'c1')!.committed.amount,
    ).toBe('49999.95');
  });

  it('counts own expenses as spent, overall and per category', async () => {
    const budget = await serviceWith(
      { totalBudgetAmount: '1000.00' },
      [{ categoryId: 'c1', plannedAmount: '500.00' }],
      [
        { categoryId: 'c1', amount: '100.10' },
        { categoryId: null, amount: '0.20' },
        { categoryId: 'c9', amount: '900.00' },
      ],
    ).get('u1', 'e1');
    expect(budget.expenses).toEqual({ amount: '1000.30', currency: 'INR' });
    expect(budget.spent).toEqual({ amount: '1000.30', currency: 'INR' });
    expect(budget.remaining).toEqual({ amount: '-0.30', currency: 'INR' });
    const line = (id: string) =>
      budget.categories.find((c) => c.categoryId === id)!;
    expect(line('c1').expenses.amount).toBe('100.10');
    expect(line('c2').expenses.amount).toBe('0.00');
    // A retired category with only expenses is still listed.
    expect(line('c9')).toMatchObject({ isArchived: true, planned: null });
    expect(line('c9').expenses.amount).toBe('900.00');
  });

  it('sums exactly and reports what is left', async () => {
    const budget = await serviceWith({ totalBudgetAmount: '1000.00' }, [
      { categoryId: 'c1', plannedAmount: '300.10' },
      { categoryId: 'c2', plannedAmount: '0.20' },
    ]).get('u1', 'e1');
    expect(budget.planned).toEqual({ amount: '300.30', currency: 'INR' });
    expect(budget.unplanned).toEqual({ amount: '699.70', currency: 'INR' });
    expect(budget.isOverPlanned).toBe(false);
    expect(budget.remaining).toEqual({ amount: '1000.00', currency: 'INR' });
    expect(budget.committed.amount).toBe('0.00');
  });

  it('flags over-planning with a negative unplanned amount', async () => {
    const budget = await serviceWith({ totalBudgetAmount: '100.00' }, [
      { categoryId: 'c1', plannedAmount: '150.00' },
    ]).get('u1', 'e1');
    expect(budget.isOverPlanned).toBe(true);
    expect(budget.unplanned).toEqual({ amount: '-50.00', currency: 'INR' });
  });

  it('without a total: no unplanned or remaining, never over-planned', async () => {
    const budget = await serviceWith({}, [
      { categoryId: 'c1', plannedAmount: '150.00' },
    ]).get('u1', 'e1');
    expect(budget).toMatchObject({
      totalBudget: null,
      unplanned: null,
      remaining: null,
      isOverPlanned: false,
    });
  });

  it('lists a plan of an archived category, flagged', async () => {
    const budget = await serviceWith({ totalBudgetAmount: '500.00' }, [
      { categoryId: 'c9', plannedAmount: '50.00' },
    ]).get('u1', 'e1');
    expect(budget.categories.map((c) => [c.name, c.isArchived])).toEqual([
      ['Venue', false],
      ['Catering', false],
      ['Fireworks', true],
    ]);
    expect(budget.planned.amount).toBe('50.00');
  });

  it('is read only for events that are not planning', async () => {
    const budget = await serviceWith({ status: 'COMPLETED' }, []).get(
      'u1',
      'e1',
    );
    expect(budget.isEditable).toBe(false);
  });
});
