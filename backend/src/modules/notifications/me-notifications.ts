import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Injectable,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  Min,
  ValidateNested,
  ArrayMaxSize,
  IsArray,
} from 'class-validator';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Enveloped } from '../../common/interceptors/response-envelope.interceptor';
import { uuidv7 } from '../../common/ids/uuid-v7';
import {
  DEFAULT_PAGE_LIMIT,
  decodeCursor,
  toCursorPage,
} from '../../common/pagination/cursor';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { PUSH_GROUPS, type PushGroup } from './push-policy';

class ListNotificationsQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = DEFAULT_PAGE_LIMIT;

  @IsOptional()
  @IsString()
  @Length(1, 512)
  cursor?: string;
}

export class RegisterDeviceDto {
  /** FCM registration token (opaque). */
  @IsString()
  @Length(20, 4096)
  token: string;

  @IsIn(['ANDROID', 'IOS'])
  platform: 'ANDROID' | 'IOS';

  @IsOptional()
  @IsString()
  @Matches(/^[0-9A-Za-z.+_-]{1,40}$/)
  appVersion?: string;
}

class PreferenceDto {
  @IsIn(PUSH_GROUPS)
  group: PushGroup;

  @IsBoolean()
  pushEnabled: boolean;
}

export class UpdatePreferencesDto {
  @IsArray()
  @ArrayMaxSize(PUSH_GROUPS.length)
  @ValidateNested({ each: true })
  @Type(() => PreferenceDto)
  preferences: PreferenceDto[];
}

export interface NotificationDto {
  id: string;
  category: string;
  type: string;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  deepLink: string | null;
  data: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
}

interface Row {
  id: string;
  category: string;
  type: string;
  title: string;
  body: string;
  entity_type: string | null;
  entity_id: string | null;
  deep_link: string | null;
  data: Record<string, unknown>;
  read_at: Date | null;
  created_at: Date;
  created_key: string;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;

/** The user's notification center, devices and push preferences (M18). */
@Injectable()
export class MeNotificationsService {
  constructor(private readonly dataSource: DataSource) {}

  async list(userId: string, limit: number, cursor?: string) {
    const params: unknown[] = [userId, limit + 1];
    let after = '';
    if (cursor) {
      const c = decodeCursor(cursor, ['c', 'i'] as const, {
        c: (v) => TIMESTAMP_PATTERN.test(v),
        i: (v) => UUID_PATTERN.test(v),
      });
      params.push(c.c, c.i);
      after = `AND (created_at, id) < ($3::timestamptz, $4::uuid)`;
    }
    const rows = await this.dataSource.query<Row[]>(
      `SELECT id, category, type, title, body, entity_type, entity_id, deep_link,
              data, read_at, created_at,
              to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS created_key
         FROM notifications
        WHERE recipient_user_id = $1 AND audience = 'USER' ${after}
        ORDER BY created_at DESC, id DESC
        LIMIT $2`,
      params,
    );
    const { items, page } = toCursorPage(rows, limit, (last) => ({
      c: last.created_key,
      i: last.id,
    }));
    return {
      items: items.map((r): NotificationDto => ({
        id: r.id,
        category: r.category,
        type: r.type,
        title: r.title,
        body: r.body,
        entityType: r.entity_type,
        entityId: r.entity_id,
        deepLink: r.deep_link,
        data: r.data,
        readAt: r.read_at ? r.read_at.toISOString() : null,
        createdAt: r.created_at.toISOString(),
      })),
      page,
    };
  }

  async unreadCount(userId: string): Promise<number> {
    const [{ count }] = await this.dataSource.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM notifications
        WHERE recipient_user_id = $1 AND audience = 'USER' AND read_at IS NULL`,
      [userId],
    );
    return count;
  }

  async markRead(userId: string, id: string): Promise<void> {
    const [, affected] = await this.dataSource.query<[unknown, number]>(
      `UPDATE notifications SET read_at = COALESCE(read_at, now())
        WHERE id = $1 AND recipient_user_id = $2 AND audience = 'USER'`,
      [id, userId],
    );
    if (!affected) {
      throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
    }
  }

  async markAllRead(userId: string): Promise<number> {
    const [, affected] = await this.dataSource.query<[unknown, number]>(
      `UPDATE notifications SET read_at = now()
        WHERE recipient_user_id = $1 AND audience = 'USER' AND read_at IS NULL`,
      [userId],
    );
    return affected;
  }

  /** A token belongs to one user: re-registering moves it (shared phone). */
  async registerDevice(userId: string, dto: RegisterDeviceDto): Promise<void> {
    await this.dataSource.query(
      `INSERT INTO notification_devices (id, user_id, audience, fcm_token, platform, app_version)
       VALUES ($1, $2, 'USER', $3, $4, $5)
       ON CONFLICT (fcm_token) DO UPDATE
         SET user_id = EXCLUDED.user_id, audience = 'USER',
             platform = EXCLUDED.platform, app_version = EXCLUDED.app_version,
             is_active = true, last_seen_at = now(), updated_at = now()`,
      [uuidv7(), userId, dto.token, dto.platform, dto.appVersion ?? null],
    );
  }

  /** Sign-out: the token stops receiving this user's pushes. */
  async removeDevice(userId: string, token: string): Promise<void> {
    await this.dataSource.query(
      `DELETE FROM notification_devices WHERE fcm_token = $1 AND user_id = $2`,
      [token, userId],
    );
  }

  async preferences(
    userId: string,
  ): Promise<{ group: PushGroup; pushEnabled: boolean }[]> {
    const rows = await this.dataSource.query<
      { push_group: PushGroup; push_enabled: boolean }[]
    >(
      `SELECT push_group, push_enabled FROM notification_preferences WHERE user_id = $1`,
      [userId],
    );
    const set = new Map(rows.map((r) => [r.push_group, r.push_enabled]));
    // Everything is on until the user turns a group off.
    return PUSH_GROUPS.map((group) => ({
      group,
      pushEnabled: set.get(group) ?? true,
    }));
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    for (const p of dto.preferences) {
      await this.dataSource.query(
        `INSERT INTO notification_preferences (user_id, push_group, push_enabled)
         VALUES ($1, $2, $3)
         ON CONFLICT (user_id, push_group) DO UPDATE
           SET push_enabled = EXCLUDED.push_enabled, updated_at = now()`,
        [userId, p.group, p.pushEnabled],
      );
    }
    return this.preferences(userId);
  }
}

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });
const WRITE_LIMIT = {
  name: 'notifications-write',
  limit: 120,
  windowSeconds: 60,
};

@Controller('me')
export class MeNotificationsController {
  constructor(private readonly me: MeNotificationsService) {}

  @Get('notifications')
  async list(
    @CurrentUser() user: RequestUser,
    @Query() query: ListNotificationsQuery,
  ): Promise<Enveloped<NotificationDto[]>> {
    const { items, page } = await this.me.list(
      user.userId,
      query.limit,
      query.cursor,
    );
    return new Enveloped(items, { page });
  }

  @Get('notifications/unread-count')
  async unread(@CurrentUser() user: RequestUser): Promise<{ count: number }> {
    return { count: await this.me.unreadCount(user.userId) };
  }

  @Post('notifications/read-all')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  async readAll(
    @CurrentUser() user: RequestUser,
  ): Promise<{ updated: number }> {
    return { updated: await this.me.markAllRead(user.userId) };
  }

  @Post('notifications/:id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async read(
    @CurrentUser() user: RequestUser,
    @Param('id', Id()) id: string,
  ): Promise<void> {
    await this.me.markRead(user.userId, id);
  }

  @Put('devices')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async register(
    @CurrentUser() user: RequestUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<void> {
    await this.me.registerDevice(user.userId, dto);
  }

  @Delete('devices/:token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async unregister(
    @CurrentUser() user: RequestUser,
    @Param('token') token: string,
  ): Promise<void> {
    await this.me.removeDevice(user.userId, token);
  }

  @Get('notification-preferences')
  preferences(@CurrentUser() user: RequestUser) {
    return this.me.preferences(user.userId);
  }

  @Put('notification-preferences')
  @RateLimit(WRITE_LIMIT)
  update(@CurrentUser() user: RequestUser, @Body() dto: UpdatePreferencesDto) {
    return this.me.updatePreferences(user.userId, dto);
  }
}
