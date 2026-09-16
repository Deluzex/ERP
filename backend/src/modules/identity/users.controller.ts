import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { Ctx } from '../../core/auth/ctx.decorator';
import { RequestContext } from '../../core/auth/request-context';
import { RequirePermission } from '../../core/auth/require-permission.decorator';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserScopesDto } from './dto/update-user-scopes.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @RequirePermission('userManagement.view')
  findAll() {
    return this.usersService.findAll();
  }

  @Get(':id')
  @RequirePermission('userManagement.view')
  findById(@Param('id') id: string) {
    return this.usersService.findById(id);
  }

  @Post()
  @RequirePermission('userManagement.create')
  create(@Body() dto: CreateUserDto, @Ctx() ctx: RequestContext) {
    return this.usersService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('userManagement.edit')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.usersService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id/scopes')
  @RequirePermission('userManagement.edit')
  updateScopes(
    @Param('id') id: string,
    @Body() dto: UpdateUserScopesDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.usersService.updateScopes(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('userManagement.delete')
  delete(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.usersService.delete(id, ctx.userId, ctx.correlationId);
  }
}
