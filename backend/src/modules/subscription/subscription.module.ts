import { Module } from '@nestjs/common';
import { AuditModule } from '../../core/audit/audit.module';
import { DatabaseModule } from '../../core/database/database.module';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionService } from './subscription.service';

@Module({
  imports: [DatabaseModule, AuditModule],
  controllers: [SubscriptionController],
  providers: [SubscriptionService],
  exports: [SubscriptionService],
})
export class SubscriptionModule {}
