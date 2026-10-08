import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FcmSender, FirebaseFcmSender } from './fcm-sender';
import {
  MeNotificationsController,
  MeNotificationsService,
} from './me-notifications';
import { NotificationEntity } from './notification.entity';
import { NotificationsService } from './notifications.service';
import { PushWorker } from './push.worker';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([NotificationEntity])],
  controllers: [MeNotificationsController],
  providers: [
    NotificationsService,
    MeNotificationsService,
    PushWorker,
    { provide: FcmSender, useClass: FirebaseFcmSender },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
