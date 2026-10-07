import type { ChecklistItemEntity } from './checklist-item.entity';
import { summarize, toChecklistItemDto } from './checklist.dto';

const item = (over: Partial<ChecklistItemEntity>): ChecklistItemEntity => ({
  id: 'i1',
  eventId: 'e1',
  title: 'Task',
  notes: null,
  dueDate: null,
  status: 'PENDING',
  completedAt: null,
  sortOrder: 0,
  deletedAt: null,
  createdAt: new Date('2026-10-01T00:00:00Z'),
  updatedAt: new Date('2026-10-01T00:00:00Z'),
  version: 1,
  ...over,
});

describe('checklist dto', () => {
  const today = '2026-10-08';

  it('marks only pending items with a past due date as overdue', () => {
    expect(
      toChecklistItemDto(item({ dueDate: '2026-10-07' }), today).isOverdue,
    ).toBe(true);
    expect(toChecklistItemDto(item({ dueDate: today }), today).isOverdue).toBe(
      false,
    );
    expect(toChecklistItemDto(item({}), today).isOverdue).toBe(false);
    expect(
      toChecklistItemDto(
        item({
          dueDate: '2026-10-01',
          status: 'DONE',
          completedAt: new Date(),
        }),
        today,
      ).isOverdue,
    ).toBe(false);
  });

  it('summarises total, done and overdue', () => {
    const items = [
      item({ dueDate: '2026-10-01' }),
      item({ status: 'DONE', completedAt: new Date() }),
      item({}),
    ].map((i) => toChecklistItemDto(i, today));
    expect(summarize(items)).toEqual({ total: 3, done: 1, overdue: 1 });
  });
});
