import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { PaymentModesController } from './controllers/payment-modes.controller';
import { PaymentsController } from './controllers/payments.controller';
import { PaymentModesService } from './services/payment-modes.service';
import { PaymentsService } from './services/payments.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [PaymentsController, PaymentModesController],
  providers: [PaymentsService, PaymentModesService],
  exports: [PaymentsService, PaymentModesService],
})
export class PaymentsModule {}
