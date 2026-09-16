import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Argon2Service } from './argon2.service';
import { AuthGuard } from './auth.guard';
import { PermissionGuard } from './permission.guard';
import { ScopeValidator } from './scope.guard';
import { TokenService } from './token.service';

@Global()
@Module({
  imports: [ConfigModule, JwtModule.register({})],
  providers: [
    Argon2Service,
    TokenService,
    AuthGuard,
    PermissionGuard,
    ScopeValidator,
  ],
  exports: [
    Argon2Service,
    TokenService,
    AuthGuard,
    PermissionGuard,
    ScopeValidator,
    JwtModule,
  ],
})
export class CoreAuthModule {}
