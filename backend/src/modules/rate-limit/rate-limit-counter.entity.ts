import { Column, Entity, PrimaryColumn } from 'typeorm';

/** Fixed-window request counters shared by all API instances (backend.md §4). */
@Entity('rate_limit_counters')
export class RateLimitCounterEntity {
  @PrimaryColumn({ name: 'bucket_key', type: 'text' })
  bucketKey: string;

  @PrimaryColumn({ name: 'window_start', type: 'timestamptz' })
  windowStart: Date;

  @Column({ type: 'integer' })
  hits: number;
}
