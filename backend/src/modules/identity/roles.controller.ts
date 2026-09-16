import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { Ctx } from '../../core/auth/ctx.decorator';
import { RequestContext } from '../../core/auth/request-context';
import { RequirePermission } from '../../core/auth/require-permission.decorator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CreateRoleDto } from './dto/create-role.dto';
import { UpdateRolePermissionsDto } from './dto/update-role-permissions.dto';
import { RolesService } from './roles.service';

@ApiTags('Identity - Roles')
@ApiBearerAuth('JWT-auth')
@Controller('roles')
export class RolesController {
  constructor(private readonly rolesService: RolesService) {}

  @Get('permissions/catalogue')
  @RequirePermission('settings.view')
  getCatalogue() {
    return this.rolesService.getCatalogue();
  }

  @Get()
  @RequirePermission('settings.view')
  findAll() {
    return this.rolesService.findAll();
  }

  @Get(':id')
  @RequirePermission('settings.view')
  findById(@Param('id') id: string) {
    return this.rolesService.findById(id);
  }

  @Post()
  @RequirePermission('settings.edit')
  create(@Body() dto: CreateRoleDto, @Ctx() ctx: RequestContext) {
    return this.rolesService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id/permissions')
  @RequirePermission('settings.edit')
  updatePermissions(
    @Param('id') id: string,
    @Body() dto: UpdateRolePermissionsDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.rolesService.updatePermissions(
      id,
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }
}
