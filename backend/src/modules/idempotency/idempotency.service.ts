import { createHash } from 'node:crypto';
import {
  HttpStatus,
  Injectable,
  Logger,
  OnApplicationShutdown,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { DataSource, type EntityManager } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { AppConfigService } from '../../config/app-config.service';
import {
  IdempotencyKeyEntity,
  type IdempotencyPrincipalType,
} from './idempotency-key.entity';

const KEY_PATTERN = /^[A-Za-z0-9-]{8,128}$/;
const TTL_MS = 24 * 60 * 60 * 1000;
const PURGE_INTERVAL_MS = 60 * 60 * 1000;

export interface IdempotentRequest {
  principalType: IdempotencyPrincipalType;
  principalId: string;
  /** Raw `Idempotency-Key` header value. */
  key: string | undefined;
  /** Route identifier, e.g. `POST /events`. */
  route: string;
  body: unknown;
}

export interface IdempotentResult<T> {
  status: number;
  body: T;
  replayed: boolean;
}

/** Deterministic JSON (sorted keys) so equal bodies hash equally. */
export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value) ?? 'null';
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(',')}]`;
  }
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${entries
    .map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`)
    .join(',')}}`;
}

/**
 * Idempotency keys (api-contracts.md §9). The key is reserved first, then the
 * handler runs in a transaction that also stores the response, so a stored
 * response always matches committed data. A failed handler releases the key.
 */
@Injectable()
export class IdempotencyService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(IdempotencyService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly dataSource: DataSource,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.config.backgroundJobsEnabled) return;
    this.timer = setInterval(
      () => void this.purgeExpiredSafely(),
      PURGE_INTERVAL_MS,
    );
    this.timer.unref();
  }

  onApplicationShutdown(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async run<T>(
    request: IdempotentRequest,
    status: number,
    handler: (manager: EntityManager) => Promise<T>,
    now = new Date(),
  ): Promise<IdempotentResult<T>> {
    const key = request.key;
    if (!key) {
      throw new AppException(
        ErrorCode.IDEMPOTENCY_KEY_REQUIRED,
        HttpStatus.PRECONDITION_REQUIRED,
        'An Idempotency-Key header is required.',
      );
    }
    if (!KEY_PATTERN.test(key)) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'Idempotency-Key',
            code: 'INVALID_IDEMPOTENCY_KEY',
            message: 'Idempotency-Key must be 8-128 letters, digits or dashes',
          },
        ],
      );
    }
    const requestHash = createHash('sha256')
      .update(stableStringify(request.body))
      .digest('hex');
    const id = {
      principalType: request.principalType,
      principalId: request.principalId,
      key,
    };
    const repo = this.dataSource.getRepository(IdempotencyKeyEntity);

    const reserved = await this.reserve(id, request.route, requestHash, now);
    if (!reserved) {
      const existing = await repo.findOneBy(id);
      if (!existing) {
        // Released between our insert attempt and read: ask the client to retry.
        throw new AppException(ErrorCode.CONFLICT, HttpStatus.CONFLICT);
      }
      if (
        existing.route !== request.route ||
        existing.requestHash !== requestHash
      ) {
        throw new AppException(
          ErrorCode.IDEMPOTENCY_KEY_REUSED,
          HttpStatus.CONFLICT,
          'This Idempotency-Key was used for a different request.',
        );
      }
      if (existing.status !== 'COMPLETED') {
        throw new AppException(
          ErrorCode.CONFLICT,
          HttpStatus.CONFLICT,
          'The same request is still being processed. Please retry shortly.',
        );
      }
      return {
        status: existing.responseStatus ?? status,
        body: existing.responseBody as T,
        replayed: true,
      };
    }

    try {
      const body = await this.dataSource.transaction(async (manager) => {
        const result = await handler(manager);
        await manager.update(IdempotencyKeyEntity, id, {
          status: 'COMPLETED',
          responseStatus: status,
          // Stored as JSON exactly as the client receives it.
          responseBody: JSON.parse(JSON.stringify(result)) as Record<
            string,
            unknown
          >,
        });
        return result;
      });
      return { status, body, replayed: false };
    } catch (error) {
      await repo
        .delete(id)
        .catch((cleanup: unknown) =>
          this.logger.warn(
            `Failed to release idempotency key (${cleanup instanceof Error ? cleanup.message : String(cleanup)})`,
          ),
        );
      throw error;
    }
  }

  /** Inserts the key as IN_PROGRESS; replaces an expired entry. */
  private async reserve(
    id: Pick<IdempotencyKeyEntity, 'principalType' | 'principalId' | 'key'>,
    route: string,
    requestHash: string,
    now: Date,
  ): Promise<boolean> {
    const rows: unknown[] = await this.dataSource.query(
      `INSERT INTO idempotency_keys
         (principal_type, principal_id, key, route, request_hash, status, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, 'IN_PROGRESS', $6, $7)
       ON CONFLICT (principal_type, principal_id, key) DO UPDATE
         SET route = EXCLUDED.route, request_hash = EXCLUDED.request_hash,
             status = 'IN_PROGRESS', response_status = NULL, response_body = NULL,
             created_at = EXCLUDED.created_at, expires_at = EXCLUDED.expires_at
         WHERE idempotency_keys.expires_at <= $6
            -- A request that never finished (process crash) frees its key.
            OR (idempotency_keys.status = 'IN_PROGRESS'
                AND idempotency_keys.created_at <= $6 - interval '60 seconds')
       RETURNING key`,
      [
        id.principalType,
        id.principalId,
        id.key,
        route,
        requestHash,
        now,
        new Date(now.getTime() + TTL_MS),
      ],
    );
    return rows.length === 1;
  }

  async purgeExpired(now = new Date()): Promise<void> {
    await this.dataSource.query(
      `DELETE FROM idempotency_keys WHERE expires_at <= $1`,
      [now],
    );
  }

  private async purgeExpiredSafely(): Promise<void> {
    try {
      await this.purgeExpired();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Idempotency key clean-up failed (${reason})`);
    }
  }
}
