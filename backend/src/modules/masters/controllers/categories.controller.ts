import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';
import { CategoriesService } from '../services/categories.service';

@ApiTags('Masters - Categories')
@ApiBearerAuth('JWT-auth')
@Controller('masters/categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  @RequirePermission('masters.view')
  findAll() {
    return this.categoriesService.findAll();
  }

  @Get(':id')
  @RequirePermission('masters.view')
  findById(@Param('id') id: string) {
    return this.categoriesService.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  create(@Body() dto: CreateCategoryDto, @Ctx() ctx: RequestContext) {
    return this.categoriesService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateCategoryDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.categoriesService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.categoriesService.delete(id, ctx.userId, ctx.correlationId);
  }
}
