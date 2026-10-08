import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  CreateExpenseDto,
  UpdateExpenseDto,
  type ExpenseDto,
  type ExpenseListDto,
} from './expenses.dto';
import { ExpensesService } from './expenses.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

// Shares the budget's write bucket: both change the same figures.
const WRITE_LIMIT = { name: 'budget-write', limit: 120, windowSeconds: 60 };

/** The owner's own expenses for an event (M11, api-contracts.md Part B). */
@Controller('events/:eventId/expenses')
export class ExpensesController {
  constructor(
    private readonly expenses: ExpensesService,
    private readonly idempotency: IdempotencyService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  list(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<ExpenseListDto> {
    return this.expenses.list(user.userId, eventId);
  }

  @Post()
  @RateLimit(WRITE_LIMIT)
  async create(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: CreateExpenseDto,
    @Headers('idempotency-key') key: string | undefined,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ExpenseDto> {
    const result = await this.idempotency.run(
      {
        principalType: 'USER',
        principalId: user.userId,
        key,
        route: `POST /events/${eventId}/expenses`,
        body: dto,
      },
      HttpStatus.CREATED,
      (manager) =>
        this.expenses.create(
          manager,
          user.userId,
          eventId,
          dto,
          contextOf(req),
        ),
    );
    res.status(result.status);
    if (result.replayed) res.setHeader('Idempotent-Replayed', 'true');
    return result.body;
  }

  @Patch(':expenseId')
  @RateLimit(WRITE_LIMIT)
  update(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('expenseId', Id()) expenseId: string,
    @Body() dto: UpdateExpenseDto,
    @Req() req: Request,
  ): Promise<ExpenseDto> {
    return this.dataSource.transaction((manager) =>
      this.expenses.update(
        manager,
        user.userId,
        eventId,
        expenseId,
        dto,
        contextOf(req),
      ),
    );
  }

  @Delete(':expenseId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @RateLimit(WRITE_LIMIT)
  async remove(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('expenseId', Id()) expenseId: string,
    @Req() req: Request,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.expenses.remove(
        manager,
        user.userId,
        eventId,
        expenseId,
        contextOf(req),
      ),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
