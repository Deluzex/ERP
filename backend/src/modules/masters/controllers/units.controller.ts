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
import { CreateUnitDto, UpdateUnitDto } from '../dto/unit.dto';
import { UnitsService } from '../services/units.service';

@ApiTags('Masters - Units')
@ApiBearerAuth('JWT-auth')
@Controller('masters/units')
export class UnitsController {
  constructor(private readonly unitsService: UnitsService) {}

  @Get()
  @RequirePermission('masters.view')
  findAll() {
    return this.unitsService.findAll();
  }

  @Get(':id')
  @RequirePermission('masters.view')
  findById(@Param('id') id: string) {
    return this.unitsService.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  create(@Body() dto: CreateUnitDto, @Ctx() ctx: RequestContext) {
    return this.unitsService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateUnitDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.unitsService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.unitsService.delete(id, ctx.userId, ctx.correlationId);
  }
}
