import {
  Injectable,
  Logger,
  OnApplicationShutdown,
  OnModuleInit,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { DatabaseHealth } from './database-health';

const RETRY_DELAY_MS = 5_000;

/**
 * Connects the TypeORM DataSource without blocking application start-up:
 * if PostgreSQL is down the API still boots, /health/ready reports 503 and
 * the connection is retried in the background.
 */
@Injectable()
export class TypeOrmDatabaseHealth
  extends DatabaseHealth
  implements OnModuleInit, OnApplicationShutdown
{
  private readonly logger = new Logger('Database');
  private retryTimer?: NodeJS.Timeout;
  private connecting?: Promise<void>;
  private shuttingDown = false;

  constructor(private readonly dataSource: DataSource) {
    super();
  }

  onModuleInit(): void {
    void this.connect();
  }

  async onApplicationShutdown(): Promise<void> {
    this.shuttingDown = true;
    clearTimeout(this.retryTimer);
    await this.connecting;
    if (this.dataSource.isInitialized) {
      await this.dataSource.destroy();
    }
  }

  async isReady(timeoutMs: number): Promise<boolean> {
    if (!this.dataSource.isInitialized) {
      void this.connect();
      return false;
    }
    let timer: NodeJS.Timeout | undefined;
    const timeout = new Promise<boolean>((resolve) => {
      timer = setTimeout(() => resolve(false), timeoutMs);
    });
    const ping = this.dataSource
      .query('SELECT 1')
      .then(() => true)
      .catch(() => false);
    try {
      return await Promise.race([ping, timeout]);
    } finally {
      clearTimeout(timer);
    }
  }

  private connect(): Promise<void> {
    if (this.shuttingDown || this.dataSource.isInitialized) {
      return Promise.resolve();
    }
    this.connecting ??= this.dataSource
      .initialize()
      .then(() => {
        this.logger.log('Connected to PostgreSQL');
      })
      .catch((err: unknown) => {
        const reason = err instanceof Error ? err.message : String(err);
        this.logger.warn(
          `PostgreSQL unavailable (${reason}); retrying in ${RETRY_DELAY_MS / 1000}s`,
        );
        if (this.shuttingDown) return;
        clearTimeout(this.retryTimer);
        this.retryTimer = setTimeout(() => void this.connect(), RETRY_DELAY_MS);
        this.retryTimer.unref();
      })
      .finally(() => {
        this.connecting = undefined;
      });
    return this.connecting;
  }
}
