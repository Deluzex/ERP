import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { AppLogger } from '../../core/logging/logger.service';
import { SalesController } from './controllers/sales.controller';
import { SalesService } from './services/sales.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [SalesController],
  providers: [SalesService, AppLogger],
  exports: [SalesService],
})
export class SalesModule {}
