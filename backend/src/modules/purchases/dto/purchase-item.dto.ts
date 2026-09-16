import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export enum PurchaseItemTypeEnum {
  rawMaterial = 'rawMaterial',
  finishedProduct = 'finishedProduct',
}

export class PurchaseLineItemDto {
  @ApiProperty({ enum: PurchaseItemTypeEnum, default: PurchaseItemTypeEnum.rawMaterial })
  @IsEnum(PurchaseItemTypeEnum)
  @IsNotEmpty()
  itemType!: PurchaseItemTypeEnum;

  @ApiPropertyOptional({ description: 'Raw Material UUID' })
  @IsUUID()
  @IsOptional()
  rawMaterialId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  rawMaterialName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  rawMaterialCode?: string;

  @ApiPropertyOptional({ description: 'Finished Product UUID' })
  @IsUUID()
  @IsOptional()
  finishedProductId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  finishedProductName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  finishedProductCode?: string;

  @ApiProperty({ description: 'Quantity purchased', example: 100.0 })
  @IsNumber()
  @Min(0.0001)
  @IsNotEmpty()
  quantity!: number;

  @ApiProperty({ description: 'Measurement unit symbol', example: 'MTR' })
  @IsString()
  @IsNotEmpty()
  unit!: string;

  @ApiProperty({ description: 'Unit purchase rate', example: 450.0 })
  @IsNumber()
  @Min(0)
  @IsNotEmpty()
  rate!: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @IsOptional()
  discountAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 18.0 })
  @IsNumber()
  @IsOptional()
  gstPercent?: number = 18.0;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  taxableAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @IsOptional()
  cgstAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @IsOptional()
  sgstAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @IsOptional()
  igstAmount?: number = 0.0;

  @ApiProperty({ description: 'Line total inclusive of tax', example: 51920.0 })
  @IsNumber()
  @IsNotEmpty()
  lineTotal!: number;
}
