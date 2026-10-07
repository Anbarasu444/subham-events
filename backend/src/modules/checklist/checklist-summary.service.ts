import { Injectable } from '@nestjs/common';
import { DataSource, type EntityManager } from 'typeorm';
import {
  EMPTY_CHECKLIST_SUMMARY,
  type ChecklistSummaryDto,
} from './checklist.dto';

/**
 * Done/total/overdue counts for many events in one aggregate query (no
 * N+1 on event lists). Overdue uses each event's own time zone.
 */
@Injectable()
export class ChecklistSummaryService {
  constructor(private readonly dataSource: DataSource) {}

  /**
   * Pass [manager] when called inside a write transaction, so the counts use
   * the uncommitted event (e.g. a new time zone) and no second pooled
   * connection is held while the event row is locked.
   */
  async forEvents(
    eventIds: string[],
    now = new Date(),
    manager?: EntityManager,
  ): Promise<Map<string, ChecklistSummaryDto>> {
    const result = new Map<string, ChecklistSummaryDto>();
    if (eventIds.length === 0) return result;
    const rows = await (manager ?? this.dataSource).query<
      { event_id: string; total: number; done: number; overdue: number }[]
    >(
      `SELECT ci.event_id,
              count(*)::int AS total,
              count(*) FILTER (WHERE ci.status = 'DONE')::int AS done,
              count(*) FILTER (
                WHERE ci.status = 'PENDING' AND ci.due_date IS NOT NULL
                  AND ci.due_date < ($2::timestamptz AT TIME ZONE e.time_zone)::date
              )::int AS overdue
         FROM checklist_items ci
         JOIN events e ON e.id = ci.event_id
        WHERE ci.event_id = ANY($1::uuid[]) AND ci.deleted_at IS NULL
        GROUP BY ci.event_id`,
      [eventIds, now],
    );
    for (const row of rows) {
      result.set(row.event_id, {
        total: row.total,
        done: row.done,
        overdue: row.overdue,
      });
    }
    return result;
  }

  async forEvent(
    eventId: string,
    now = new Date(),
    manager?: EntityManager,
  ): Promise<ChecklistSummaryDto> {
    return (
      (await this.forEvents([eventId], now, manager)).get(eventId) ?? {
        ...EMPTY_CHECKLIST_SUMMARY,
      }
    );
  }
}
