import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { ProductionStatusEnum } from './production-order.dto';

export class ProductionQueryDto {
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
  @Max(200)
  @IsOptional()
  limit?: number = 50;

  @ApiPropertyOptional({ enum: ProductionStatusEnum })
  @IsEnum(ProductionStatusEnum)
  @IsOptional()
  status?: ProductionStatusEnum;

  @ApiPropertyOptional({ description: 'Filter by Finished Product UUID' })
  @IsUUID()
  @IsOptional()
  finishedProductId?: string;

  @ApiPropertyOptional({ description: 'Filter by Sales Order UUID' })
  @IsUUID()
  @IsOptional()
  salesOrderId?: string;

  @ApiPropertyOptional({ description: 'Filter by Project UUID' })
  @IsUUID()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({ description: 'Filter by from date (ISO string)' })
  @IsString()
  @IsOptional()
  fromDate?: string;

  @ApiPropertyOptional({ description: 'Filter by to date (ISO string)' })
  @IsString()
  @IsOptional()
  toDate?: string;

  @ApiPropertyOptional({ description: 'Search production number, product name, or code' })
  @IsString()
  @IsOptional()
  search?: string;
}
