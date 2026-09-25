import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { CreatePurchaseDto } from '../dto/create-purchase.dto';
import {
  PurchaseQueryDto,
  UpdatePurchaseStatusDto,
} from '../dto/purchase-query.dto';
import { PurchasesService } from '../services/purchases.service';

@ApiTags('Purchase & Procurement')
@ApiBearerAuth('JWT-auth')
@Controller('purchases')
export class PurchasesController {
  constructor(private readonly purchasesService: PurchasesService) {}

  @Get()
  @RequirePermission('purchase.view')
  @ApiOperation({
    summary: 'List purchase orders and inward bills with summary KPIs',
  })
  findAll(@Query() query: PurchaseQueryDto) {
    return this.purchasesService.findAll(query);
  }

  @Get(':id')
  @RequirePermission('purchase.view')
  @ApiOperation({
    summary: 'Get purchase order details, line items, and payment vouchers',
  })
  findById(@Param('id') id: string) {
    return this.purchasesService.findById(id);
  }

  @Post()
  @RequirePermission('purchase.create')
  @ApiOperation({
    summary:
      'Create purchase order / inward bill, increment inventory stock, post stock movement, and update vendor balance',
  })
  create(@Body() dto: CreatePurchaseDto, @Ctx() ctx: RequestContext) {
    return this.purchasesService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Patch(':id/status')
  @RequirePermission('purchase.edit')
  @ApiOperation({
    summary:
      'Update purchase order workflow status, with automatic stock and balance rollback on cancellation',
  })
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdatePurchaseStatusDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.purchasesService.updateStatus(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }
}
