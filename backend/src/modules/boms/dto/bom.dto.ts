import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export enum BomStatusEnum {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  OBSOLETE = 'OBSOLETE',
}

export class CreateBomItemDto {
  @IsUUID()
  @IsNotEmpty()
  rawMaterialId!: string;

  @IsNumber()
  @Min(0.0001)
  quantity!: number;

  @IsString()
  @IsOptional()
  unit?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  scrapPercentage?: number;

  @IsString()
  @IsOptional()
  itemNotes?: string;
}

export class CreateBomDto {
  @IsUUID()
  @IsNotEmpty()
  finishedProductId!: string;

  @IsNumber()
  @Min(0.0001)
  @IsOptional()
  yieldQuantity?: number;

  @IsEnum(BomStatusEnum)
  @IsOptional()
  status?: BomStatusEnum;

  @IsString()
  @IsOptional()
  notes?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateBomItemDto)
  items!: CreateBomItemDto[];
}

export class UpdateBomDto {
  @IsNumber()
  @Min(0.0001)
  @IsOptional()
  yieldQuantity?: number;

  @IsString()
  @IsOptional()
  notes?: string;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CreateBomItemDto)
  items?: CreateBomItemDto[];
}

export class UpdateBomStatusDto {
  @IsIn(['DRAFT', 'ACTIVE', 'OBSOLETE'])
  @IsNotEmpty()
  status!: BomStatusEnum;
}

export class BomQueryDto {
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  page?: number;

  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  limit?: number;

  @IsString()
  @IsOptional()
  search?: string;

  @IsUUID()
  @IsOptional()
  productId?: string;

  @IsIn(['DRAFT', 'ACTIVE', 'OBSOLETE'])
  @IsOptional()
  status?: BomStatusEnum;
}
