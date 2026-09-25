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
  CreateFinishedProductDto,
  UpdateFinishedProductDto,
} from '../dto/finished-product.dto';
import { FinishedProductsService } from '../services/finished-products.service';

@ApiTags('Masters - Finished Products')
@ApiBearerAuth('JWT-auth')
@Controller('masters/finished-products')
export class FinishedProductsController {
  constructor(
    private readonly finishedProductsService: FinishedProductsService,
  ) {}

  @Get()
  @RequirePermission('masters.view')
  findAll(
    @Query('search') search?: string,
    @Query('categoryId') categoryId?: string,
    @Query('includeDeleted') includeDeleted?: string,
  ) {
    return this.finishedProductsService.findAll(
      search,
      categoryId,
      includeDeleted === 'true',
    );
  }

  @Get(':id')
  @RequirePermission('masters.view')
  findById(@Param('id') id: string) {
    return this.finishedProductsService.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  create(@Body() dto: CreateFinishedProductDto, @Ctx() ctx: RequestContext) {
    return this.finishedProductsService.create(
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateFinishedProductDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.finishedProductsService.update(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.finishedProductsService.delete(
      id,
      ctx.userId,
      ctx.correlationId,
    );
  }
}
