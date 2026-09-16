import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { PurchasesController } from './controllers/purchases.controller';
import { PurchasesService } from './services/purchases.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [PurchasesController],
  providers: [PurchasesService],
  exports: [PurchasesService],
})
export class PurchasesModule {}
