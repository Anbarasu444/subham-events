import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { RateLimitModule } from '../rate-limit/rate-limit.module';
import { UsersModule } from '../users/users.module';
import { AuthController } from './auth.controller';
import { FirebaseAuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { FirebaseAdminVerifier } from './firebase-admin.verifier';
import { TokenVerifier } from './token-verifier';

@Module({
  imports: [UsersModule, RateLimitModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    { provide: TokenVerifier, useClass: FirebaseAdminVerifier },
    { provide: APP_GUARD, useClass: FirebaseAuthGuard },
  ],
})
export class AuthModule {}
