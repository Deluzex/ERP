import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { ExpenseCategoriesController } from './controllers/expense-categories.controller';
import { ExpensesController } from './controllers/expenses.controller';
import { ExpenseCategoriesService } from './services/expense-categories.service';
import { ExpensesService } from './services/expenses.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [ExpensesController, ExpenseCategoriesController],
  providers: [ExpensesService, ExpenseCategoriesService],
  exports: [ExpensesService, ExpenseCategoriesService],
})
export class ExpensesModule {}
