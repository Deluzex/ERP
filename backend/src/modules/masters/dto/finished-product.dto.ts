import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateFinishedProductDto {
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
  costPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  dealerSellingPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  customerSellingPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  gstPercent?: number;
}

export class UpdateFinishedProductDto {
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
  costPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  dealerSellingPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  customerSellingPrice?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  gstPercent?: number;
}
