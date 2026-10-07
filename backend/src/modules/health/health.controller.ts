import { Controller, Get } from '@nestjs/common';
import { Public } from '../auth/auth.decorators';
import { HealthService, HealthStatus } from './health.service';

/** Liveness/readiness probes — public (api-contracts.md Part B). */
@Public()
@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Get('live')
  live(): HealthStatus {
    return this.health.live();
  }

  @Get('ready')
  ready(): Promise<HealthStatus> {
    return this.health.ready();
  }
}
