import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { getRequestId } from '../../common/logging/request-id';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { DeleteAccountDto } from '../users/me.dto';
import { AccountDeletionService } from './account-deletion.service';
import { CheckRevoked } from './auth.decorators';
import { CurrentUser } from './current-user.decorator';
import type { RequestUser } from './request-user';

/** Self-service account deletion (M21). */
@Controller('me')
export class AccountController {
  constructor(private readonly deletion: AccountDeletionService) {}

  @Post('delete')
  @HttpCode(HttpStatus.NO_CONTENT)
  @CheckRevoked()
  @RateLimit({ name: 'account-delete', limit: 5, windowSeconds: 60 })
  async delete(
    @CurrentUser() user: RequestUser,
    // Validated: the user typed DELETE.
    @Body() _dto: DeleteAccountDto,
    @Req() req: Request,
  ): Promise<void> {
    await this.deletion.delete(user.userId, user.firebaseUid, {
      requestId: getRequestId(req),
      ip: req.ip,
    });
  }
}
