import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MediaModule } from '../media/media.module';
import { UserRoleEntity } from './entities/user-role.entity';
import { UserEntity } from './entities/user.entity';
import { MeController } from './me.controller';
import { ProfileService } from './profile.service';
import { UsersService } from './users.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity, UserRoleEntity]),
    MediaModule,
  ],
  controllers: [MeController],
  providers: [UsersService, ProfileService],
  exports: [UsersService, ProfileService],
})
export class UsersModule {}
