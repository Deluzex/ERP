import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { RolesController } from './roles.controller';
import { RolesService } from './roles.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [RolesController, UsersController],
  providers: [RolesService, UsersService],
  exports: [RolesService, UsersService],
})
export class IdentityModule {}
