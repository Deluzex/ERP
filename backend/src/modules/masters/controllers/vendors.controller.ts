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
  CreateVendorDto,
  DeleteVendorDto,
  UpdateVendorDto,
} from '../dto/vendor.dto';
import { VendorsService } from '../services/vendors.service';

@ApiTags('Masters - Vendors')
@ApiBearerAuth('JWT-auth')
@Controller('masters/vendors')
export class VendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @Get()
  @RequirePermission('masters.view')
  findAll(
    @Query('search') search?: string,
    @Query('includeDeleted') includeDeleted?: string,
  ) {
    return this.vendorsService.findAll(search, includeDeleted === 'true');
  }

  @Get(':id')
  @RequirePermission('masters.view')
  findById(@Param('id') id: string) {
    return this.vendorsService.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  create(@Body() dto: CreateVendorDto, @Ctx() ctx: RequestContext) {
    return this.vendorsService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateVendorDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.vendorsService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('masters.delete')
  delete(
    @Param('id') id: string,
    @Body() dto: DeleteVendorDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.vendorsService.delete(id, dto, ctx.userId, ctx.correlationId);
  }
}
