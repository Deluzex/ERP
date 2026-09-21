import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { ExpensesController } from './controllers/expenses.controller';
import { ExpensesService } from './services/expenses.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [ExpensesController],
  providers: [ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}
