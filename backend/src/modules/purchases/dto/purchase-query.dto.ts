import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
import { PaymentModeEnum, PurchaseStatusEnum } from './create-purchase.dto';
import { PurchaseItemTypeEnum } from './purchase-item.dto';

export class PurchaseQueryDto {
  @ApiPropertyOptional({ default: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page?: number = 1;

  @ApiPropertyOptional({ default: 50 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  limit?: number = 50;

  @ApiPropertyOptional({ enum: PurchaseStatusEnum })
  @IsEnum(PurchaseStatusEnum)
  @IsOptional()
  status?: PurchaseStatusEnum;

  @ApiPropertyOptional({ enum: PurchaseItemTypeEnum })
  @IsEnum(PurchaseItemTypeEnum)
  @IsOptional()
  purchaseType?: PurchaseItemTypeEnum;

  @ApiPropertyOptional({ description: 'Filter by vendor UUID' })
  @IsUUID()
  @IsOptional()
  vendorId?: string;

  @ApiPropertyOptional({ description: 'Start date filter (ISO8601)' })
  @IsString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({ description: 'End date filter (ISO8601)' })
  @IsString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({ description: 'Search PO number, invoice number, or vendor' })
  @IsString()
  @IsOptional()
  search?: string;
}

export class UpdatePurchaseStatusDto {
  @ApiPropertyOptional({ enum: PurchaseStatusEnum })
  @IsEnum(PurchaseStatusEnum)
  status!: PurchaseStatusEnum;

  @ApiPropertyOptional({ description: 'Cancellation or amendment reason' })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiPropertyOptional({ description: 'Cancellation reason alias' })
  @IsString()
  @IsOptional()
  cancelReason?: string;
}
