import {
  Body,
  Controller,
  Delete,
  Get,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Put,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { getRequestId } from '../../common/logging/request-id';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { SetAllocationDto, type BudgetDto } from './budget.dto';
import { BudgetService } from './budget.service';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'budget-write', limit: 120, windowSeconds: 60 };

/** An event's budget (M11, api-contracts.md Part B). */
@Controller('events/:eventId/budget')
export class BudgetController {
  constructor(
    private readonly budget: BudgetService,
    private readonly dataSource: DataSource,
  ) {}

  @Get()
  get(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<BudgetDto> {
    return this.budget.get(user.userId, eventId);
  }

  /** Idempotent by nature (same amount → same state). */
  @Put('allocations/:categoryId')
  @RateLimit(WRITE_LIMIT)
  set(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('categoryId', Id()) categoryId: string,
    @Body() dto: SetAllocationDto,
    @Req() req: Request,
  ): Promise<BudgetDto> {
    return this.dataSource.transaction((manager) =>
      this.budget.setAllocation(
        manager,
        user.userId,
        eventId,
        categoryId,
        dto.planned.toMoney(),
        contextOf(req),
      ),
    );
  }

  @Delete('allocations/:categoryId')
  @RateLimit(WRITE_LIMIT)
  clear(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Param('categoryId', Id()) categoryId: string,
    @Req() req: Request,
  ): Promise<BudgetDto> {
    return this.dataSource.transaction((manager) =>
      this.budget.clearAllocation(
        manager,
        user.userId,
        eventId,
        categoryId,
        contextOf(req),
      ),
    );
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
