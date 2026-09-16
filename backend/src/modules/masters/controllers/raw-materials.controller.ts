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
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  CreateRawMaterialDto,
  UpdateRawMaterialDto,
} from '../dto/raw-material.dto';
import { RawMaterialsService } from '../services/raw-materials.service';

@ApiTags('Masters - Raw Materials')
@ApiBearerAuth('JWT-auth')
@Controller('masters/raw-materials')
export class RawMaterialsController {
  constructor(private readonly rawMaterialsService: RawMaterialsService) {}

  @Get()
  @RequirePermission('masters.view')
  findAll(
    @Query('search') search?: string,
    @Query('categoryId') categoryId?: string,
    @Query('lowStockOnly') lowStockOnly?: string,
    @Query('includeDeleted') includeDeleted?: string,
  ) {
    return this.rawMaterialsService.findAll(
      search,
      categoryId,
      lowStockOnly === 'true',
      includeDeleted === 'true',
    );
  }

  @Get(':id')
  @RequirePermission('masters.view')
  findById(@Param('id') id: string) {
    return this.rawMaterialsService.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  create(@Body() dto: CreateRawMaterialDto, @Ctx() ctx: RequestContext) {
    return this.rawMaterialsService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateRawMaterialDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.rawMaterialsService.update(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.rawMaterialsService.delete(id, ctx.userId, ctx.correlationId);
  }
}
