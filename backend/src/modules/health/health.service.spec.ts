import { HttpStatus } from '@nestjs/common';
import { AppException } from '../../common/errors/app.exception';
import { DatabaseHealth } from '../../database/database-health';
import { HealthService } from './health.service';

class FakeDatabaseHealth extends DatabaseHealth {
  constructor(public up: boolean) {
    super();
  }
  isReady(): Promise<boolean> {
    return Promise.resolve(this.up);
  }
}

describe('HealthService', () => {
  it('reports live without touching the database', () => {
    expect(new HealthService(new FakeDatabaseHealth(false)).live()).toEqual({
      status: 'ok',
    });
  });

  it('reports ready when the database is up', async () => {
    await expect(
      new HealthService(new FakeDatabaseHealth(true)).ready(),
    ).resolves.toEqual({ status: 'ok', checks: { database: 'up' } });
  });

  it('throws SERVICE_UNAVAILABLE when the database is down', async () => {
    const promise = new HealthService(new FakeDatabaseHealth(false)).ready();
    await expect(promise).rejects.toBeInstanceOf(AppException);
    await promise.catch((e: AppException) => {
      expect(e.code).toBe('SERVICE_UNAVAILABLE');
      expect(e.getStatus()).toBe(HttpStatus.SERVICE_UNAVAILABLE);
    });
  });
});
