import { Injectable } from '@nestjs/common';
import type { EntityManager } from 'typeorm';
import type { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { ActorType, AuditLogEntity } from './audit-log.entity';

export interface AuditEntry {
  actorType: ActorType;
  actorId?: string | null;
  actorRole?: string | null;
  action: string;
  entityType: string;
  entityId?: string | null;
  requestId?: string | null;
  ip?: string | null;
  /** Small before/after summary of business fields — never secrets or PII beyond ids. */
  summary?: Record<string, unknown>;
  reason?: string | null;
}

@Injectable()
export class AuditService {
  /** Writes inside the caller's transaction so the audit row commits with the change. */
  async record(manager: EntityManager, entry: AuditEntry): Promise<void> {
    const row: QueryDeepPartialEntity<AuditLogEntity> = {
      id: uuidv7(),
      actorType: entry.actorType,
      actorId: entry.actorId ?? null,
      actorRole: entry.actorRole ?? null,
      action: entry.action,
      entityType: entry.entityType,
      entityId: entry.entityId ?? null,
      requestId: entry.requestId ?? null,
      ip: entry.ip ?? null,
      // jsonb column: TypeORM serialises the object.
      summary: (entry.summary ?? {}) as QueryDeepPartialEntity<
        AuditLogEntity['summary']
      >,
      reason: entry.reason ?? null,
    };
    await manager.insert(AuditLogEntity, row);
  }
}
