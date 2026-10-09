import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Req,
  Res,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import type { Request, Response } from 'express';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { getRequestId } from '../../common/logging/request-id';
import { AppConfigService } from '../../config/app-config.service';
import { Public } from '../auth/auth.decorators';
import { CurrentUser } from '../auth/current-user.decorator';
import type { RequestUser } from '../auth/request-user';
import type { RequestContext } from '../events/events.service';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import {
  GUEST_PAGE_HEADERS,
  renderInvitationPage,
  renderUnavailablePage,
} from './guest-page';
import {
  GuestRsvpDto,
  RsvpOpenDto,
  SaveInvitationDto,
  type InvitationDto,
  type RsvpDto,
  type RsvpTotals,
} from './invitations.dto';
import { InvitationsService, newToken } from './invitations.service';
import { INVITATION_TEMPLATES, type InvitationTemplate } from './templates';

const Id = () =>
  new ParseUUIDPipe({
    exceptionFactory: () =>
      new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND),
  });

const WRITE_LIMIT = { name: 'invitations-write', limit: 60, windowSeconds: 60 };

/** Where guests open the invitation (until a link domain exists, ADR-0010). */
function shareUrl(
  config: AppConfigService,
  req: Request,
  token: string,
): string {
  const origin =
    config.invitationBaseUrl ?? `${req.protocol}://${req.get('host')}`;
  return `${origin}/api/v1/i/${token}`;
}

/** The owner's invitation for an event (M19, api-contracts.md Part B). */
@Controller('events/:eventId/invitation')
export class InvitationsController {
  constructor(
    private readonly invitations: InvitationsService,
    private readonly dataSource: DataSource,
    private readonly config: AppConfigService,
  ) {}

  @Get()
  async get(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<{ invitation: InvitationDto | null }> {
    return { invitation: await this.invitations.get(user.userId, eventId) };
  }

  /** Create or update (naturally idempotent: one invitation per event). */
  @Put()
  @RateLimit(WRITE_LIMIT)
  save(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: SaveInvitationDto,
    @Req() req: Request,
  ): Promise<InvitationDto> {
    return this.dataSource.transaction((m) =>
      this.invitations.save(m, user.userId, eventId, dto, contextOf(req)),
    );
  }

  /** Returns the share link once; only its hash is stored. */
  @Post('publish')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  async publish(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Req() req: Request,
  ): Promise<{ invitation: InvitationDto; shareUrl: string }> {
    const { invitation, token } = await this.dataSource.transaction((m) =>
      this.invitations.publish(m, user.userId, eventId, contextOf(req)),
    );
    return { invitation, shareUrl: shareUrl(this.config, req, token) };
  }

  /** A new link for a published invitation; the old link stops working. */
  @Post('new-link')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  async newLink(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Req() req: Request,
  ): Promise<{ invitation: InvitationDto; shareUrl: string }> {
    const { invitation, token } = await this.dataSource.transaction((m) =>
      this.invitations.newLink(m, user.userId, eventId, contextOf(req)),
    );
    return { invitation, shareUrl: shareUrl(this.config, req, token) };
  }

  @Post('rsvp-open')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  rsvpOpen(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Body() dto: RsvpOpenDto,
    @Req() req: Request,
  ): Promise<InvitationDto> {
    return this.dataSource.transaction((m) =>
      this.invitations.setRsvpOpen(
        m,
        user.userId,
        eventId,
        dto.open,
        contextOf(req),
      ),
    );
  }

  @Post('revoke')
  @HttpCode(HttpStatus.OK)
  @RateLimit(WRITE_LIMIT)
  revoke(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
    @Req() req: Request,
  ): Promise<InvitationDto> {
    return this.dataSource.transaction((m) =>
      this.invitations.revoke(m, user.userId, eventId, contextOf(req)),
    );
  }

  @Get('rsvps')
  rsvps(
    @CurrentUser() user: RequestUser,
    @Param('eventId', Id()) eventId: string,
  ): Promise<{ totals: RsvpTotals; rsvps: RsvpDto[] }> {
    return this.invitations.rsvps(user.userId, eventId);
  }
}

/** The design catalogue (public; the app and guest pages share it). */
@Controller('invitation-templates')
export class InvitationTemplatesController {
  @Get()
  @Public()
  list(): readonly InvitationTemplate[] {
    return INVITATION_TEMPLATES;
  }
}

const GUEST_READ = { name: 'invitation-page', limit: 60, windowSeconds: 60 };
const GUEST_WRITE = { name: 'invitation-rsvp', limit: 10, windowSeconds: 60 };
const COOKIE = 'rsvp_id';

function responderCookie(req: Request): string | null {
  const header = req.headers.cookie ?? '';
  for (const part of header.split(';')) {
    const [name, ...rest] = part.trim().split('=');
    if (name === COOKIE) {
      const value = rest.join('=');
      return /^[A-Za-z0-9_-]{43}$/.test(value) ? value : null;
    }
  }
  return null;
}

/**
 * Public guest pages (no login; A6): a small server-rendered page with the
 * RSVP form. The browser keeps an RSVP cookie so a guest can change their
 * reply. Plain HTML responses, outside the JSON envelope.
 */
@Controller('i')
export class GuestInvitationController {
  constructor(private readonly invitations: InvitationsService) {}

  @Get(':token')
  @Public()
  @RateLimit(GUEST_READ)
  async page(
    @Param('token') token: string,
    @Req() req: Request,
    @Res() res: Response,
  ): Promise<void> {
    res.set(GUEST_PAGE_HEADERS);
    const pub = await this.invitations.findPublic(token);
    if (!pub) {
      res.status(HttpStatus.NOT_FOUND).send(renderUnavailablePage());
      return;
    }
    const responder = responderCookie(req);
    const existing = responder
      ? await this.invitations.guestRsvp(pub.invitation.id, responder)
      : null;
    const sent =
      req.query.sent === '1'
        ? 'sent'
        : req.query.invalid === '1'
          ? 'invalid'
          : null;
    res
      .status(HttpStatus.OK)
      .send(
        renderInvitationPage(
          { ...pub.invitation, template: pub.template, rsvpOpen: pub.rsvpOpen },
          { formAction: `./${token}/rsvp`, existing, notice: sent },
        ),
      );
  }

  @Post(':token/rsvp')
  @Public()
  @RateLimit(GUEST_WRITE)
  async rsvp(
    @Param('token') token: string,
    @Body() body: Record<string, unknown>,
    @Req() req: Request,
    @Res() res: Response,
  ): Promise<void> {
    res.set(GUEST_PAGE_HEADERS);
    const pub = await this.invitations.findPublic(token);
    if (!pub) {
      res.status(HttpStatus.NOT_FOUND).send(renderUnavailablePage());
      return;
    }
    // Validated here (not by the global pipe) so a mistake re-shows the page.
    const dto = plainToInstance(GuestRsvpDto, {
      guestName: body.guestName,
      response: body.response,
      guestCount: body.guestCount,
      message: body.message,
    });
    if (validateSync(dto).length > 0) {
      res.redirect(HttpStatus.SEE_OTHER, `../${token}?invalid=1`);
      return;
    }
    const responder = responderCookie(req) ?? newToken();
    try {
      await this.invitations.submitRsvp(pub, responder, dto, req.ip);
    } catch (error) {
      if (error instanceof AppException) {
        res.redirect(HttpStatus.SEE_OTHER, `../${token}`);
        return;
      }
      throw error;
    }
    res.cookie(COOKIE, responder, {
      httpOnly: true,
      sameSite: 'lax',
      secure: req.secure,
      maxAge: 365 * 24 * 60 * 60 * 1000,
      path: `/api/v1/i/${token}`,
    });
    res.redirect(HttpStatus.SEE_OTHER, `../${token}?sent=1`);
  }
}

function contextOf(req: Request): RequestContext {
  return { requestId: getRequestId(req), ip: req.ip };
}
