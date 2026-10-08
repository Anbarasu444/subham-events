import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEntity } from '../events/event.entity';
import { CoverUrlService } from './cover-url.service';
import { HttpImageKitClient, ImageKitClient } from './imagekit.client';
import { MediaCleanupJob } from './media-cleanup.job';
import { MediaController } from './media.controller';
import { MediaEntity } from './media.entity';
import { MediaService } from './media.service';

@Module({
  imports: [TypeOrmModule.forFeature([MediaEntity, EventEntity])],
  controllers: [MediaController],
  providers: [
    MediaService,
    CoverUrlService,
    MediaCleanupJob,
    { provide: ImageKitClient, useClass: HttpImageKitClient },
  ],
  exports: [CoverUrlService, ImageKitClient],
})
export class MediaModule {}
