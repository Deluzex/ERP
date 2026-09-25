import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateRawMaterialDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  itemCode!: string;

  @IsString()
  @IsNotEmpty()
  categoryId!: string;

  @IsString()
  @IsNotEmpty()
  unitId!: string;

  @IsString()
  @IsOptional()
  hsnSacCode?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  openingStock?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  minimumStock?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  reorderLevel?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultPurchasePrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  gstPercent?: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  preferredVendorIds?: string[];
}

export class UpdateRawMaterialDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  unitId?: string;

  @IsString()
  @IsOptional()
  hsnSacCode?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  minimumStock?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  reorderLevel?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultPurchasePrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  gstPercent?: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  preferredVendorIds?: string[];
}
