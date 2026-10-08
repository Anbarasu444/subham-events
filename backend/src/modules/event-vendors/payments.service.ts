import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { Money } from '../../common/money/money';
import { AuditService } from '../audit/audit.service';
import { localDate } from '../events/event-rules';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { BookingEntity } from './booking.entity';
import { PaymentNoteEntity } from './payment-note.entity';
import {
  MAX_PAYMENTS,
  toPaymentDto,
  type CreatePaymentDto,
  type PaymentDto,
  type PaymentListDto,
  type UpdatePaymentDto,
} from './payments.dto';

/**
 * The user's private payment notes per booking (M16; R5, A2, A3, A11).
 * Owner-only through the event (404 otherwise). Allowed for confirmed,
 * completed and cancelled bookings, while the event is planning, completed
 * or cancelled (answer 5). No notifications (A2); audited without amounts
 * or text.
 */
@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly audit: AuditService,
  ) {}

  async list(
    userId: string,
    eventId: string,
    bookingId: string,
  ): Promise<PaymentListDto> {
    const manager = this.events.manager;
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    const booking = await this.findBooking(manager, eventId, bookingId);
    return this.listFor(manager, booking);
  }

  async create(
    manager: EntityManager,
    userId: string,
    eventId: string,
    bookingId: string,
    dto: CreatePaymentDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<PaymentDto> {
    const event = await this.lockOwned(manager, userId, eventId);
    const booking = await this.findBooking(manager, eventId, bookingId);
    const amount = validAmount(dto.amount.toMoney(), booking.currency);
    notInFuture(dto.paidOn, event, now);
    const [{ count }] = await manager.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM event_payment_notes
        WHERE booking_id = $1 AND deleted_at IS NULL`,
      [bookingId],
    );
    if (count >= MAX_PAYMENTS) {
      throw new AppException(
        ErrorCode.LIMIT_REACHED,
        HttpStatus.CONFLICT,
        `A booking can have at most ${MAX_PAYMENTS} payments.`,
      );
    }
    const repo = manager.getRepository(PaymentNoteEntity);
    const saved = await repo.save(
      repo.create({
        id: uuidv7(),
        bookingId,
        eventId,
        userId,
        kind: dto.kind,
        amount: amount.toString(),
        currency: amount.currency,
        paidOn: dto.paidOn,
        method: dto.method,
        note: dto.note ?? null,
        deletedAt: null,
      }),
    );
    await this.record(
      manager,
      userId,
      'PAYMENT_NOTE_CREATED',
      saved.id,
      context,
      {
        eventId,
        bookingId,
      },
    );
    return toPaymentDto(saved);
  }

  async update(
    manager: EntityManager,
    userId: string,
    eventId: string,
    bookingId: string,
    paymentId: string,
    dto: UpdatePaymentDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<PaymentDto> {
    const event = await this.lockOwned(manager, userId, eventId);
    const booking = await this.findBooking(manager, eventId, bookingId);
    const note = await this.findNote(manager, bookingId, paymentId);
    if (note.version !== dto.version) {
      throw new AppException(
        ErrorCode.PRECONDITION_FAILED,
        HttpStatus.PRECONDITION_FAILED,
        'This payment was changed elsewhere. Reload and try again.',
      );
    }
    const changed: string[] = [];
    if (dto.amount !== undefined) {
      const amount = validAmount(dto.amount.toMoney(), booking.currency);
      if (!Money.fromDb(note.amount, note.currency).equals(amount)) {
        note.amount = amount.toString();
        changed.push('amount');
      }
    }
    if (dto.paidOn !== undefined && dto.paidOn !== note.paidOn) {
      notInFuture(dto.paidOn, event, now);
      note.paidOn = dto.paidOn;
      changed.push('paidOn');
    }
    for (const field of ['method', 'kind', 'note'] as const) {
      const value = dto[field];
      if (value !== undefined && value !== note[field]) {
        (note as unknown as Record<string, unknown>)[field] = value;
        changed.push(field);
      }
    }
    if (changed.length === 0) return toPaymentDto(note);
    const saved = await manager.getRepository(PaymentNoteEntity).save(note);
    await this.record(
      manager,
      userId,
      'PAYMENT_NOTE_UPDATED',
      note.id,
      context,
      {
        eventId,
        bookingId,
        fields: changed,
      },
    );
    return toPaymentDto(saved);
  }

  /** Soft delete (R11). */
  async remove(
    manager: EntityManager,
    userId: string,
    eventId: string,
    bookingId: string,
    paymentId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    await this.lockOwned(manager, userId, eventId);
    await this.findBooking(manager, eventId, bookingId);
    const note = await this.findNote(manager, bookingId, paymentId);
    note.deletedAt = now;
    await manager.getRepository(PaymentNoteEntity).save(note);
    await this.record(
      manager,
      userId,
      'PAYMENT_NOTE_DELETED',
      note.id,
      context,
      {
        eventId,
        bookingId,
      },
    );
  }

  private async listFor(
    manager: EntityManager,
    booking: BookingEntity,
  ): Promise<PaymentListDto> {
    const notes = await manager.getRepository(PaymentNoteEntity).find({
      where: { bookingId: booking.id, deletedAt: IsNull() },
      order: { paidOn: 'DESC', createdAt: 'DESC', id: 'DESC' },
    });
    const agreed = Money.fromDb(booking.agreedAmount, booking.currency);
    const paid = notes.reduce(
      (sum, n) => sum.add(Money.fromDb(n.amount, n.currency)),
      Money.zero(),
    );
    const balance = agreed.subtract(paid);
    return {
      bookingId: booking.id,
      bookingStatus: booking.status,
      agreedAmount: agreed.toJSON(),
      paid: paid.toJSON(),
      balance: balance.isNegative() ? null : balance.toJSON(),
      overpaidBy: balance.isNegative() ? paid.subtract(agreed).toJSON() : null,
      payments: notes.map(toPaymentDto),
    };
  }

  private async findBooking(
    manager: EntityManager,
    eventId: string,
    bookingId: string,
  ): Promise<BookingEntity> {
    const booking = await manager
      .getRepository(BookingEntity)
      .findOneBy({ id: bookingId, eventId });
    if (!booking) throw notFound();
    return booking;
  }

  private async findNote(
    manager: EntityManager,
    bookingId: string,
    paymentId: string,
  ): Promise<PaymentNoteEntity> {
    const note = await manager
      .getRepository(PaymentNoteEntity)
      .findOneBy({ id: paymentId, bookingId, deletedAt: IsNull() });
    if (!note) throw notFound();
    return note;
  }

  /** The owner's (not deleted) event in any status, row-locked. */
  private async lockOwned(
    manager: EntityManager,
    userId: string,
    eventId: string,
  ): Promise<EventEntity> {
    const event = await manager
      .getRepository(EventEntity)
      .createQueryBuilder('e')
      .setLock('pessimistic_write')
      .where('e.id = :eventId', { eventId })
      .andWhere('e.owner_user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL')
      .getOne();
    if (!event) throw notFound();
    return event;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    paymentId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    // Ids and field names only: amounts and notes are the user's private data.
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'PAYMENT_NOTE',
      entityId: paymentId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

function validAmount(amount: Money, currency: string): Money {
  if (amount.currency !== currency) {
    throw invalid(
      'amount.currency',
      'CURRENCY_MISMATCH',
      'amount.currency must match the booking currency',
    );
  }
  if (amount.isNegative() || amount.equals(Money.zero(amount.currency))) {
    throw invalid(
      'amount',
      'AMOUNT_NOT_POSITIVE',
      'amount must be more than 0.00',
    );
  }
  return amount;
}

function notInFuture(paidOn: string, event: EventEntity, now: Date): void {
  if (paidOn > localDate(event.timeZone, now)) {
    throw invalid('paidOn', 'DATE_IN_FUTURE', 'paidOn cannot be in the future');
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}

function invalid(field: string, code: string, message: string): AppException {
  return new AppException(
    ErrorCode.VALIDATION_FAILED,
    HttpStatus.UNPROCESSABLE_ENTITY,
    undefined,
    [{ field, code, message }],
  );
}
