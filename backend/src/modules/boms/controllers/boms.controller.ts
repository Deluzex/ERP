import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import {
  BomQueryDto,
  CreateBomDto,
  UpdateBomDto,
  UpdateBomStatusDto,
} from '../dto/bom.dto';
import { BomsService } from '../services/boms.service';

@ApiTags('Bill of Materials (BOM) Master')
@ApiBearerAuth('JWT-auth')
@Controller('boms')
export class BomsController {
  constructor(private readonly bomsService: BomsService) {}

  @Get()
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'List BOM recipes with pagination & filters' })
  findAll(@Query() query: BomQueryDto) {
    return this.bomsService.findAll(query);
  }

  @Get('by-product/:productId')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'Get currently active BOM by finished product ID' })
  getActiveBomByProduct(@Param('productId') productId: string) {
    return this.bomsService.getActiveBomByProduct(productId);
  }

  @Get(':id')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'Get BOM recipe details by ID including itemized components' })
  findById(@Param('id') id: string) {
    return this.bomsService.findById(id);
  }

  @Post()
  @RequirePermission('production.create')
  @ApiOperation({ summary: 'Create new Bill of Materials (BOM) recipe' })
  create(@Body() dto: CreateBomDto, @Ctx() ctx: RequestContext) {
    return this.bomsService.create(dto, ctx.userId);
  }

  @Put(':id')
  @RequirePermission('production.edit')
  @ApiOperation({ summary: 'Update draft BOM recipe (Active/Obsolete are locked)' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateBomDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.bomsService.update(id, dto, ctx.userId);
  }

  @Post(':id/duplicate')
  @RequirePermission('production.create')
  @ApiOperation({ summary: 'Duplicate/clone BOM into next version DRAFT' })
  duplicate(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.bomsService.duplicate(id, ctx.userId);
  }

  @Patch(':id/status')
  @RequirePermission('production.edit')
  @ApiOperation({ summary: 'Update BOM lifecycle status (DRAFT -> ACTIVE -> OBSOLETE)' })
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateBomStatusDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.bomsService.updateStatus(id, dto.status, ctx.userId);
  }

  @Get(':id/cost-rollup')
  @RequirePermission('production.view')
  @ApiOperation({ summary: 'Dynamic cost rollup vs live raw material purchase prices' })
  getCostRollup(@Param('id') id: string) {
    return this.bomsService.getCostRollup(id);
  }
}
