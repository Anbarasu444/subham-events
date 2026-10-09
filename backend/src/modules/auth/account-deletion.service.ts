import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import type { DataSource, EntityManager } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { AuditService } from '../audit/audit.service';
import { closeLiveEnquiries } from '../event-vendors/event-vendors.service';
import { NotificationsService } from '../notifications/notifications.service';
import { cancelReminders } from '../reminders/reminders.service';
import { UsersService } from '../users/users.service';
import type { RequestContext } from './auth.service';
import { TokenVerifier } from './token-verifier';

export const ACCOUNT_DELETED_REASON = 'Account deleted';

/**
 * Self-service account deletion (M21; R11 interim policy, A8 as changed by
 * the user): the account is marked DELETED and **all data is kept**; the
 * user's planning events are cancelled, confirmed bookings cancelled (the
 * vendor is told, N13), reminders cancelled, invitation links turned off and
 * devices unregistered. Signing in again restores the account.
 */
@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly verifier: TokenVerifier,
  ) {}

  async delete(
    userId: string,
    firebaseUid: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const [user] = await manager.query<
        { status: string; display_name: string | null }[]
      >(`SELECT status, display_name FROM users WHERE id = $1 FOR UPDATE`, [
        userId,
      ]);
      if (!user) {
        throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
      }
      if (user.status === 'DELETED') return;
      const bookings = await this.cancelBookings(
        manager,
        userId,
        user.display_name?.trim() || 'A customer',
        now,
      );
      const events = await this.cancelEvents(manager, userId, now);
      const [, invitations] = await manager.query<[unknown[], number]>(
        `UPDATE invitations SET status = 'REVOKED', revoked_at = $2,
                share_token_hash = NULL, updated_at = $2, version = version + 1
          WHERE user_id = $1 AND status = 'PUBLISHED'`,
        [userId, now],
      );
      await manager.query(
        `UPDATE notification_devices SET is_active = false, updated_at = $2
          WHERE user_id = $1 AND is_active`,
        [userId, now],
      );
      await manager.query(
        `UPDATE users SET status = 'DELETED', deleted_at = $2,
                status_changed_at = $2, updated_at = $2, version = version + 1
          WHERE id = $1`,
        [userId, now],
      );
      await this.audit.record(manager, {
        actorType: 'USER',
        actorId: userId,
        action: 'ACCOUNT_DELETED',
        entityType: 'USER',
        entityId: userId,
        requestId: context.requestId,
        ip: context.ip,
        summary: {
          bookingsCancelled: bookings,
          eventsCancelled: events,
          invitationsRevoked: invitations,
        },
      });
    });
    this.users.invalidate(firebaseUid);
    // Sign out everywhere. Best effort: the account is already DELETED, so
    // every API call is refused even if Firebase is unreachable now.
    try {
      await this.verifier.revokeRefreshTokens(firebaseUid);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Token revocation after deletion failed (${reason})`);
    }
  }

  /** Confirmed bookings → CANCELLED "Account deleted"; vendors get N13. */
  private async cancelBookings(
    manager: EntityManager,
    userId: string,
    customerName: string,
    now: Date,
  ): Promise<number> {
    const [rows] = await manager.query<
      [
        {
          id: string;
          event_id: string;
          event_vendor_id: string;
          service_date: string;
        }[],
        number,
      ]
    >(
      `UPDATE bookings SET status = 'CANCELLED', cancelled_by_type = 'USER',
              cancel_reason = $3, cancelled_at = $2, status_changed_at = $2,
              updated_at = $2, version = version + 1
        WHERE user_id = $1 AND status = 'CONFIRMED'
        RETURNING id, event_id, event_vendor_id, service_date::text AS service_date`,
      [userId, now, ACCOUNT_DELETED_REASON],
    );
    for (const b of rows) {
      await manager.query(
        `UPDATE event_vendors SET status = 'CANCELLED', status_changed_at = $2,
                updated_at = $2, version = version + 1
          WHERE id = $1 AND status = 'BOOKED'`,
        [b.event_vendor_id, now],
      );
      const [owner] = await manager.query<
        { user_id: string; title: string; event_type: string; city: string }[]
      >(
        `SELECT v.user_id, l.title, e.event_type, e.city
           FROM event_vendors ev
           JOIN vendor_listings l ON l.id = ev.listing_id
           JOIN vendors v ON v.id = l.vendor_id
           JOIN events e ON e.id = ev.event_id
          WHERE ev.id = $1`,
        [b.event_vendor_id],
      );
      await this.notifications.createInApp(manager, {
        recipientUserId: owner.user_id,
        audience: 'VENDOR',
        category: 'BOOKING',
        type: 'BOOKING_CANCELLED',
        title: 'Booking cancelled',
        body: `${customerName} cancelled the booking for “${owner.title}” on ${b.service_date}.`,
        entityType: 'BOOKING',
        entityId: b.id,
        data: {
          customerName,
          eventType: owner.event_type,
          city: owner.city,
          reason: ACCOUNT_DELETED_REASON,
        },
      });
      await this.audit.record(manager, {
        actorType: 'USER',
        actorId: userId,
        action: 'BOOKING_CANCELLED',
        entityType: 'BOOKING',
        entityId: b.id,
        summary: { eventId: b.event_id, by: 'USER', accountDeleted: true },
      });
    }
    return rows.length;
  }

  /** Planning events → CANCELLED; open enquiries closed; reminders off. */
  private async cancelEvents(
    manager: EntityManager,
    userId: string,
    now: Date,
  ): Promise<number> {
    const [cancelled] = await manager.query<[{ id: string }[], number]>(
      `UPDATE events SET status = 'CANCELLED', status_changed_at = $2,
              updated_at = $2, version = version + 1
        WHERE owner_user_id = $1 AND status = 'PLANNING' AND deleted_at IS NULL
        RETURNING id`,
      [userId, now],
    );
    const all = await manager.query<{ id: string }[]>(
      `SELECT id FROM events WHERE owner_user_id = $1`,
      [userId],
    );
    for (const e of all) {
      await closeLiveEnquiries(manager, { eventId: e.id }, 'SYSTEM', now);
      await cancelReminders(manager, { eventId: e.id }, 'EVENT_CANCELLED', now);
    }
    return cancelled.length;
  }
}
