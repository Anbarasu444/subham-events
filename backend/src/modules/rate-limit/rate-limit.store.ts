import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import type { DataSource } from 'typeorm';

export abstract class RateLimitStore {
  /** Increments the counter for the window and returns the new hit count. */
  abstract hit(bucketKey: string, windowStart: Date): Promise<number>;
}

/** PostgreSQL-backed counters so limits hold across instances. */
@Injectable()
export class PostgresRateLimitStore extends RateLimitStore {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {
    super();
  }

  async hit(bucketKey: string, windowStart: Date): Promise<number> {
    const rows: { hits: number }[] = await this.dataSource.query(
      `INSERT INTO rate_limit_counters (bucket_key, window_start, hits)
       VALUES ($1, $2, 1)
       ON CONFLICT (bucket_key, window_start)
       DO UPDATE SET hits = rate_limit_counters.hits + 1
       RETURNING hits`,
      [bucketKey, windowStart],
    );
    // Occasionally purge expired windows (technical data, not business data).
    if (Math.random() < 0.01) {
      await this.dataSource.query(
        `DELETE FROM rate_limit_counters WHERE window_start < now() - interval '1 day'`,
      );
    }
    return rows[0].hits;
  }
}

/** For tests and single-process tools. */
export class InMemoryRateLimitStore extends RateLimitStore {
  private readonly counters = new Map<string, number>();

  clear(): void {
    this.counters.clear();
  }

  hit(bucketKey: string, windowStart: Date): Promise<number> {
    const key = `${bucketKey}|${windowStart.toISOString()}`;
    const hits = (this.counters.get(key) ?? 0) + 1;
    this.counters.set(key, hits);
    return Promise.resolve(hits);
  }
}
