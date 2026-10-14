import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Put,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import {
  CreatePaymentModeDto,
  UpdatePaymentModeDto,
  UpdatePaymentModeStatusDto,
} from '../dto/payment-mode.dto';
import { PaymentModesService } from '../services/payment-modes.service';

@ApiTags('Payment Modes')
@ApiBearerAuth('JWT-auth')
@Controller('payment-modes')
export class PaymentModesController {
  constructor(private readonly service: PaymentModesService) {}

  @Get()
  @RequirePermission('masters.view')
  @ApiOperation({ summary: 'List all payment modes' })
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  @RequirePermission('masters.view')
  @ApiOperation({ summary: 'Get payment mode by ID' })
  findById(@Param('id') id: string) {
    return this.service.findById(id);
  }

  @Post()
  @RequirePermission('masters.create')
  @ApiOperation({ summary: 'Create new payment mode' })
  create(@Body() dto: CreatePaymentModeDto) {
    return this.service.create(dto);
  }

  @Put(':id')
  @RequirePermission('masters.edit')
  @ApiOperation({ summary: 'Update payment mode' })
  update(@Param('id') id: string, @Body() dto: UpdatePaymentModeDto) {
    return this.service.update(id, dto);
  }

  @Patch(':id/status')
  @RequirePermission('masters.edit')
  @ApiOperation({ summary: 'Toggle active status of payment mode' })
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdatePaymentModeStatusDto,
  ) {
    return this.service.updateStatus(id, dto.isActive);
  }
}
