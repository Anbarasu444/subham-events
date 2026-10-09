import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventEntity } from '../events/event.entity';
import { InvitationEntity } from './invitation.entity';
import {
  GuestInvitationController,
  InvitationTemplatesController,
  InvitationsController,
} from './invitations.controller';
import { InvitationsService } from './invitations.service';
import { RsvpDigestJob } from './rsvp-digest.job';

@Module({
  imports: [TypeOrmModule.forFeature([InvitationEntity, EventEntity])],
  controllers: [
    InvitationsController,
    InvitationTemplatesController,
    GuestInvitationController,
  ],
  providers: [InvitationsService, RsvpDigestJob],
})
export class InvitationsModule {}
