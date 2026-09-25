import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { CreateExpenseDto } from '../dto/create-expense.dto';
import { ExpenseQueryDto } from '../dto/expense-query.dto';
import { UpdateExpenseDto } from '../dto/update-expense.dto';
import { ExpensesService } from '../services/expenses.service';

@ApiTags('Expenses & Operational Vouchers')
@ApiBearerAuth('JWT-auth')
@Controller('expenses')
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get()
  @RequirePermission('payments.view')
  @ApiOperation({
    summary: 'List expense vouchers with summary KPIs and category filters',
  })
  findAll(@Query() query: ExpenseQueryDto) {
    return this.expensesService.findAll(query);
  }

  @Get(':id')
  @RequirePermission('payments.view')
  @ApiOperation({
    summary: 'Get expense voucher by ID',
  })
  findById(@Param('id') id: string) {
    return this.expensesService.findById(id);
  }

  @Post()
  @RequirePermission('payments.create')
  @ApiOperation({
    summary: 'Create expense voucher with sequential expense number',
  })
  create(@Body() dto: CreateExpenseDto, @Ctx() ctx: RequestContext) {
    return this.expensesService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('payments.edit')
  @ApiOperation({
    summary: 'Update expense voucher details',
  })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateExpenseDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.expensesService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('payments.delete')
  @ApiOperation({
    summary: 'Delete expense voucher',
  })
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.expensesService.delete(id, ctx.userId, ctx.correlationId);
  }
}
