import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { MediaService } from './media.service';

const INTERVAL_MS = 60 * 60 * 1000;

/** Hourly: uploads started but never completed within 24 h are rejected. */
@Injectable()
export class MediaCleanupJob
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(MediaCleanupJob.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly media: MediaService,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.config.backgroundJobsEnabled) return;
    this.timer = setInterval(() => void this.runSafely(), INTERVAL_MS);
    this.timer.unref();
  }

  onApplicationShutdown(): void {
    if (this.timer) clearInterval(this.timer);
  }

  private async runSafely(): Promise<void> {
    try {
      const count = await this.media.rejectAbandoned();
      if (count > 0) this.logger.log(`Rejected ${count} abandoned upload(s)`);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Media clean-up failed (${reason})`);
    }
  }
}
