import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { CreateBomDto } from '../dto/bom.dto';
import {
  CancelProductionOrderDto,
  CreateProductionOrderDto,
} from '../dto/production-order.dto';
import { ProductionQueryDto } from '../dto/production-query.dto';
import { ProductionService } from '../services/production.service';

@ApiTags('Production & Manufacturing')
@ApiBearerAuth('JWT-auth')
@Controller('production')
export class ProductionController {
  constructor(private readonly productionService: ProductionService) {}

  @Get('orders')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'List production work orders with financial summary metrics' })
  findAll(@Query() query: ProductionQueryDto) {
    return this.productionService.findAll(query);
  }

  @Get('orders/:id')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'Get production order details by ID including materials consumed' })
  findById(@Param('id') id: string) {
    return this.productionService.findById(id);
  }

  @Post('orders')
  @RequirePermission('production.create')
  @ApiOperation({ summary: 'Create & complete production batch (atomic material consumption & output)' })
  create(@Body() dto: CreateProductionOrderDto, @Ctx() ctx: RequestContext) {
    return this.productionService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Delete('orders/:id')
  @RequirePermission('production.delete')
  @ApiOperation({ summary: 'Cancel & soft-delete production order with automatic stock rollback' })
  cancel(
    @Param('id') id: string,
    @Body() dto: CancelProductionOrderDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.productionService.cancel(id, dto, ctx.userId, ctx.correlationId);
  }

  @Get('bom/:finishedProductId')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'Get active Bill of Materials (BOM) recipe for finished product' })
  getBom(@Param('finishedProductId') finishedProductId: string) {
    return this.productionService.getBomByProductId(finishedProductId);
  }

  @Post('bom')
  @RequirePermission('production.create')
  @ApiOperation({ summary: 'Create or update Bill of Materials (BOM) recipe for finished product' })
  createBom(@Body() dto: CreateBomDto, @Ctx() ctx: RequestContext) {
    return this.productionService.createOrUpdateBom(dto, ctx.userId);
  }
}
