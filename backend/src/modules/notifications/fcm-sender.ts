import { Injectable, Logger } from '@nestjs/common';
import {
  App,
  applicationDefault,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { AppConfigService } from '../../config/app-config.service';

export interface PushMessage {
  title: string;
  body: string;
  /** All string values (FCM data payload). */
  data: Record<string, string>;
  androidChannelId: string;
  /** iOS thread grouping. */
  threadId: string;
}

/** Per-token outcome of a send. */
export type PushResult = 'SENT' | 'INVALID_TOKEN' | 'RETRY';

/** Sends pushes; abstract so tests never call Firebase. */
export abstract class FcmSender {
  abstract send(tokens: string[], message: PushMessage): Promise<PushResult[]>;
}

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Firebase Admin messaging, with the same credentials as auth (M5). */
@Injectable()
export class FirebaseFcmSender extends FcmSender {
  private readonly logger = new Logger('FcmSender');
  private app?: App;

  constructor(private readonly config: AppConfigService) {
    super();
  }

  async send(tokens: string[], message: PushMessage): Promise<PushResult[]> {
    if (tokens.length === 0) return [];
    try {
      const response = await getMessaging(this.firebase()).sendEachForMulticast(
        {
          tokens,
          notification: { title: message.title, body: message.body },
          data: message.data,
          android: {
            priority: 'high',
            notification: { channelId: message.androidChannelId },
          },
          apns: { payload: { aps: { threadId: message.threadId } } },
        },
      );
      return response.responses.map((r) => {
        if (r.success) return 'SENT';
        const code = r.error?.code ?? '';
        return INVALID_TOKEN_CODES.has(code) ? 'INVALID_TOKEN' : 'RETRY';
      });
    } catch (error) {
      // Missing credentials or an outage: try again later.
      const code = (error as { code?: unknown }).code;
      this.logger.warn(
        `Push send failed (${typeof code === 'string' ? code : 'unknown'})`,
      );
      return tokens.map(() => 'RETRY');
    }
  }

  private firebase(): App {
    if (this.app) return this.app;
    this.app =
      getApps()[0] ??
      initializeApp({
        credential: applicationDefault(),
        projectId: this.config.firebaseProjectId,
      });
    return this.app;
  }
}
