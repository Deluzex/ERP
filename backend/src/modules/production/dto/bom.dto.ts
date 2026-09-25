import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class BomItemDto {
  @ApiProperty({ description: 'Raw Material UUID' })
  @IsUUID()
  @IsNotEmpty()
  rawMaterialId!: string;

  @ApiProperty({ description: 'Raw Material Name' })
  @IsString()
  @IsNotEmpty()
  rawMaterialName!: string;

  @ApiPropertyOptional({ description: 'Raw Material Item Code' })
  @IsString()
  @IsOptional()
  rawMaterialCode?: string;

  @ApiProperty({ description: 'Quantity required per unit of finished good', example: 1.2 })
  @IsNumber()
  @Min(0.0001)
  @IsNotEmpty()
  quantityPerUnit!: number;

  @ApiProperty({ description: 'Measurement unit', example: 'kg' })
  @IsString()
  @IsNotEmpty()
  unit!: string;
}

export class CreateBomDto {
  @ApiProperty({ description: 'Finished Product UUID' })
  @IsUUID()
  @IsNotEmpty()
  finishedProductId!: string;

  @ApiProperty({ description: 'BOM Recipe Name', example: 'Standard Architectural Bar Recipe' })
  @IsString()
  @IsNotEmpty()
  name!: string;

  @ApiPropertyOptional({ description: 'Description / manufacturing notes' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ description: 'Standard output quantity batch', default: 1.0 })
  @IsNumber()
  @Min(0.0001)
  @IsOptional()
  outputQuantity?: number = 1.0;

  @ApiPropertyOptional({ default: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean = true;

  @ApiProperty({ type: [BomItemDto], description: 'Required raw materials in recipe' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BomItemDto)
  @IsNotEmpty()
  items!: BomItemDto[];
}
