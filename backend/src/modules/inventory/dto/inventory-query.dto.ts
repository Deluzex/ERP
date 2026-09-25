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
import { ItemTypeEnum } from './stock-adjustment.dto';

export enum StockMovementTypeEnum {
  purchase = 'purchase',
  productionConsumption = 'productionConsumption',
  productionOutput = 'productionOutput',
  sale = 'sale',
  saleReturn = 'saleReturn',
  purchaseReturn = 'purchaseReturn',
  damage = 'damage',
  adjustment = 'adjustment',
}

export class PaginationQueryDto {
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
}

export class StockMovementQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter by item UUID' })
  @IsUUID()
  @IsOptional()
  itemId?: string;

  @ApiPropertyOptional({ enum: ItemTypeEnum })
  @IsEnum(ItemTypeEnum)
  @IsOptional()
  itemType?: ItemTypeEnum;

  @ApiPropertyOptional({ enum: StockMovementTypeEnum })
  @IsEnum(StockMovementTypeEnum)
  @IsOptional()
  transactionType?: StockMovementTypeEnum;

  @ApiPropertyOptional({ description: 'Filter from start date (ISO8601)' })
  @IsString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({ description: 'Filter to end date (ISO8601)' })
  @IsString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({ description: 'Search reference, item name/code' })
  @IsString()
  @IsOptional()
  search?: string;
}

export class StockFilterQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Search text (name, code)' })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiPropertyOptional({ description: 'Filter by category UUID' })
  @IsUUID()
  @IsOptional()
  categoryId?: string;

  @ApiPropertyOptional({ description: 'Filter items where currentStock <= minimumStock' })
  @IsOptional()
  isLowStock?: string;
}
