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
import {
  CreateArchitectDto,
  LinkArchitectCustomerDto,
  UpdateArchitectDto,
} from '../dto/architect.dto';
import { CreateCustomerDto, UpdateCustomerDto } from '../dto/customer.dto';
import { CreateDealerDto, UpdateDealerDto } from '../dto/dealer.dto';
import { PartiesService } from '../services/parties.service';

@Controller('masters')
export class PartiesController {
  constructor(private readonly partiesService: PartiesService) {}

  // -------------------------------------------------------------
  // CUSTOMERS
  // -------------------------------------------------------------
  @Get('customers')
  @RequirePermission('masters.view')
  findAllCustomers(
    @Query('search') search?: string,
    @Query('isAlsoArchitect') isAlsoArchitect?: string,
  ) {
    return this.partiesService.findAllCustomers(
      search,
      isAlsoArchitect === undefined ? undefined : isAlsoArchitect === 'true',
    );
  }

  @Get('customers/:id')
  @RequirePermission('masters.view')
  findCustomerById(@Param('id') id: string) {
    return this.partiesService.findCustomerById(id);
  }

  @Post('customers')
  @RequirePermission('masters.create')
  createCustomer(@Body() dto: CreateCustomerDto, @Ctx() ctx: RequestContext) {
    return this.partiesService.createCustomer(dto, ctx.userId, ctx.correlationId);
  }

  @Put('customers/:id')
  @RequirePermission('masters.edit')
  updateCustomer(
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.partiesService.updateCustomer(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete('customers/:id')
  @RequirePermission('masters.delete')
  deleteCustomer(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.partiesService.deleteCustomer(id, ctx.userId, ctx.correlationId);
  }

  // -------------------------------------------------------------
  // DEALERS
  // -------------------------------------------------------------
  @Get('dealers')
  @RequirePermission('masters.view')
  findAllDealers(@Query('search') search?: string) {
    return this.partiesService.findAllDealers(search);
  }

  @Get('dealers/:id')
  @RequirePermission('masters.view')
  findDealerById(@Param('id') id: string) {
    return this.partiesService.findDealerById(id);
  }

  @Post('dealers')
  @RequirePermission('masters.create')
  createDealer(@Body() dto: CreateDealerDto, @Ctx() ctx: RequestContext) {
    return this.partiesService.createDealer(dto, ctx.userId, ctx.correlationId);
  }

  @Put('dealers/:id')
  @RequirePermission('masters.edit')
  updateDealer(
    @Param('id') id: string,
    @Body() dto: UpdateDealerDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.partiesService.updateDealer(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete('dealers/:id')
  @RequirePermission('masters.delete')
  deleteDealer(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.partiesService.deleteDealer(id, ctx.userId, ctx.correlationId);
  }

  // -------------------------------------------------------------
  // ARCHITECTS
  // -------------------------------------------------------------
  @Get('architects')
  @RequirePermission('masters.view')
  findAllArchitects(@Query('search') search?: string) {
    return this.partiesService.findAllArchitects(search);
  }

  @Get('architects/:id')
  @RequirePermission('masters.view')
  findArchitectById(@Param('id') id: string) {
    return this.partiesService.findArchitectById(id);
  }

  @Post('architects')
  @RequirePermission('masters.create')
  createArchitect(@Body() dto: CreateArchitectDto, @Ctx() ctx: RequestContext) {
    return this.partiesService.createArchitect(dto, ctx.userId, ctx.correlationId);
  }

  @Put('architects/:id')
  @RequirePermission('masters.edit')
  updateArchitect(
    @Param('id') id: string,
    @Body() dto: UpdateArchitectDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.partiesService.updateArchitect(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete('architects/:id')
  @RequirePermission('masters.delete')
  deleteArchitect(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.partiesService.deleteArchitect(id, ctx.userId, ctx.correlationId);
  }

  // -------------------------------------------------------------
  // DUAL IDENTITY LINKING
  // -------------------------------------------------------------
  @Post('link-architect-customer')
  @RequirePermission('masters.edit')
  linkArchitectCustomer(
    @Body() dto: LinkArchitectCustomerDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.partiesService.linkArchitectAndCustomer(
      dto,
      ctx.userId,
      ctx.correlationId,
    );
  }
}
