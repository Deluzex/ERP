import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { AuditModule } from './core/audit/audit.module';
import { AuthGuard } from './core/auth/auth.guard';
import { CoreAuthModule } from './core/auth/auth.module';
import { PermissionGuard } from './core/auth/permission.guard';
import { DatabaseModule } from './core/database/database.module';
import { GlobalExceptionFilter } from './core/errors/global-exception.filter';
import { CorrelationIdMiddleware } from './core/interceptors/correlation-id.middleware';
import { ResponseEnvelopeInterceptor } from './core/interceptors/response-envelope.interceptor';
import { AppLogger } from './core/logging/logger.service';
import { AuthModule } from './modules/auth/auth.module';
import { IdentityModule } from './modules/identity/identity.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    DatabaseModule,
    AuditModule,
    CoreAuthModule,
    AuthModule,
    IdentityModule,
  ],
  providers: [
    AppLogger,
    {
      provide: APP_GUARD,
      useClass: AuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: PermissionGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: ResponseEnvelopeInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: GlobalExceptionFilter,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(CorrelationIdMiddleware).forRoutes('*');
  }
}
