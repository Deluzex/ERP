import { Global, Module } from '@nestjs/common';
import { AppLogger } from '../logging/logger.service';
import { AuditService } from './audit.service';

@Global()
@Module({
  providers: [AuditService, AppLogger],
  exports: [AuditService],
})
export class AuditModule {}
