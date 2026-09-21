import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { CreatePaymentDto } from '../dto/create-payment.dto';
import {
  CommissionQueryDto,
  DisburseCommissionDto,
  PaymentQueryDto,
  RejectCommissionDto,
} from '../dto/payment-query.dto';
import { PaymentsService } from '../services/payments.service';

@ApiTags('Payments, Receipts & Commissions')
@ApiBearerAuth('JWT-auth')
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('commissions')
  @RequirePermission('payments.view')
  @ApiOperation({
    summary: 'List architect referral commissions with KPI totals',
  })
  listCommissions(@Query() query: CommissionQueryDto) {
    return this.paymentsService.listCommissions(query);
  }

  @Post('commissions/:id/approve')
  @RequirePermission('payments.approve')
  @ApiOperation({
    summary: 'Approve architect referral commission for payout',
  })
  approveCommission(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.paymentsService.approveCommission(id, ctx.userId, ctx.correlationId);
  }

  @Post('commissions/:id/pay')
  @RequirePermission('payments.create')
  @ApiOperation({
    summary: 'Disburse payout for approved architect commission',
  })
  disburseCommission(
    @Param('id') id: string,
    @Body() dto: DisburseCommissionDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.paymentsService.disburseCommission(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Post('commissions/:id/reject')
  @RequirePermission('payments.edit')
  @ApiOperation({
    summary: 'Reject architect commission referral with reason',
  })
  rejectCommission(
    @Param('id') id: string,
    @Body() dto: RejectCommissionDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.paymentsService.rejectCommission(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Get()
  @RequirePermission('payments.view')
  @ApiOperation({
    summary: 'List payment vouchers with KPI summaries and filters',
  })
  findAll(@Query() query: PaymentQueryDto) {
    return this.paymentsService.findAll(query);
  }

  @Get(':id')
  @RequirePermission('payments.view')
  @ApiOperation({
    summary: 'Get payment voucher by ID',
  })
  findById(@Param('id') id: string) {
    return this.paymentsService.findById(id);
  }

  @Post()
  @RequirePermission('payments.create')
  @ApiOperation({
    summary:
      'Record payment voucher (Customer receipt, Dealer collection, Vendor payment) with atomic ledger rebalancing',
  })
  recordPayment(@Body() dto: CreatePaymentDto, @Ctx() ctx: RequestContext) {
    return this.paymentsService.recordPayment(dto, ctx.userId, ctx.correlationId);
  }
}
