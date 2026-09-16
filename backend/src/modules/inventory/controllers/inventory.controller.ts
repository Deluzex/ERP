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
import {
  PaginationQueryDto,
  StockFilterQueryDto,
  StockMovementQueryDto,
} from '../dto/inventory-query.dto';
import { TriggerLowStockAlertDto } from '../dto/low-stock-alert.dto';
import { CreateStockAdjustmentDto } from '../dto/stock-adjustment.dto';
import { InventoryService } from '../services/inventory.service';

@ApiTags('Inventory & Warehouse')
@ApiBearerAuth('JWT-auth')
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('raw-materials')
  @RequirePermission('inventory.view')
  @ApiOperation({ summary: 'Get raw materials inventory stock and valuations' })
  getRawMaterials(@Query() query: StockFilterQueryDto) {
    return this.inventoryService.getRawMaterialsStock(query);
  }

  @Get('finished-products')
  @RequirePermission('inventory.view')
  @ApiOperation({
    summary: 'Get finished products inventory, reserved and available stock',
  })
  getFinishedProducts(@Query() query: StockFilterQueryDto) {
    return this.inventoryService.getFinishedProductsStock(query);
  }

  @Get('stock-movements')
  @RequirePermission('inventory.view')
  @ApiOperation({
    summary: 'Get immutable stock ledger movements with audit metadata',
  })
  getStockMovements(@Query() query: StockMovementQueryDto) {
    return this.inventoryService.getStockMovements(query);
  }

  @Post('stock-adjustments')
  @RequirePermission('inventory.create')
  @ApiOperation({
    summary:
      'Perform stock adjustment variance reconciliation with row locking and audit ledger insertion',
  })
  performStockAdjustment(
    @Body() dto: CreateStockAdjustmentDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.inventoryService.performStockAdjustment(
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Get('stock-adjustments')
  @RequirePermission('inventory.view')
  @ApiOperation({ summary: 'List historical stock adjustments' })
  getStockAdjustments(@Query() query: PaginationQueryDto) {
    return this.inventoryService.getStockAdjustments(query);
  }

  @Post('trigger-low-stock-alert')
  @RequirePermission('inventory.create')
  @ApiOperation({
    summary: 'Trigger and record low stock WhatsApp alert notification',
  })
  triggerLowStockAlert(
    @Body() dto: TriggerLowStockAlertDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.inventoryService.triggerLowStockAlert(dto, ctx.userId);
  }

  @Get('low-stock-alerts')
  @RequirePermission('inventory.view')
  @ApiOperation({ summary: 'Get low stock alert logs' })
  getLowStockAlerts(@Query() query: PaginationQueryDto) {
    return this.inventoryService.getLowStockAlerts(query);
  }

  @Patch('low-stock-alerts/:id/resolve')
  @RequirePermission('inventory.edit')
  @ApiOperation({ summary: 'Resolve a low stock alert record' })
  resolveLowStockAlert(
    @Param('id') id: string,
    @Ctx() ctx: RequestContext,
  ) {
    return this.inventoryService.resolveLowStockAlert(id, ctx.userId);
  }
}
