import { HttpStatus, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { DatabaseHealth } from '../../database/database-health';

export interface HealthStatus {
  status: 'ok';
  checks?: Record<string, 'up'>;
}

const DB_CHECK_TIMEOUT_MS = 2_000;

@Injectable()
export class HealthService {
  constructor(private readonly database: DatabaseHealth) {}

  live(): HealthStatus {
    return { status: 'ok' };
  }

  async ready(): Promise<HealthStatus> {
    const dbUp = await this.database.isReady(DB_CHECK_TIMEOUT_MS);
    if (!dbUp) {
      throw new AppException(
        ErrorCode.SERVICE_UNAVAILABLE,
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
    return { status: 'ok', checks: { database: 'up' } };
  }
}
