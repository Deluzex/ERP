import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import {
  CreateExpenseCategoryDto,
  ExpenseCategoryQueryDto,
  UpdateExpenseCategoryDto,
  UpdateExpenseCategoryStatusDto,
} from '../dto/expense-category.dto';
import { ExpenseCategoriesService } from '../services/expense-categories.service';

@ApiTags('Expense Categories')
@ApiBearerAuth('JWT-auth')
@Controller('expense-categories')
export class ExpenseCategoriesController {
  constructor(private readonly service: ExpenseCategoriesService) {}

  @Get()
  @RequirePermission('masters.view')
  @ApiOperation({ summary: 'List expense categories with search and pagination' })
  findAll(@Query() query: ExpenseCategoryQueryDto) {
    return this.service.findAll(query);
  }

  @Get(':id')
  @RequirePermission('masters.view')
  @ApiOperation({ summary: 'Get single expense category by ID' })
  findById(@Param('id') id: string) {
    return this.service.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  @ApiOperation({ summary: 'Create new expense category' })
  create(@Body() dto: CreateExpenseCategoryDto) {
    return this.service.create(dto);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  @ApiOperation({ summary: 'Update expense category' })
  update(@Param('id') id: string, @Body() dto: UpdateExpenseCategoryDto) {
    return this.service.update(id, dto);
  }

  @Patch(':id/status')
  @RequirePermission('masters.edit')
  @ApiOperation({ summary: 'Toggle active status of expense category' })
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateExpenseCategoryStatusDto,
  ) {
    return this.service.updateStatus(id, dto.isActive);
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  @ApiOperation({ summary: 'Delete expense category' })
  delete(@Param('id') id: string) {
    return this.service.delete(id);
  }
}
