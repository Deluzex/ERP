import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export enum ProductionStatusEnum {
  planned = 'planned',
  inProgress = 'inProgress',
  completed = 'completed',
  cancelled = 'cancelled',
}

export class ProductionRawMaterialUsageDto {
  @ApiProperty({ description: 'Raw Material UUID' })
  @IsUUID()
  @IsNotEmpty()
  rawMaterialId!: string;

  @ApiPropertyOptional({ description: 'Raw Material Name' })
  @IsString()
  @IsOptional()
  rawMaterialName?: string;

  @ApiPropertyOptional({ description: 'Raw Material Item Code' })
  @IsString()
  @IsOptional()
  rawMaterialCode?: string;

  @ApiProperty({ description: 'Quantity consumed', example: 25.0 })
  @IsNumber()
  @Min(0.0001)
  @IsNotEmpty()
  quantityUsed!: number;

  @ApiPropertyOptional({ description: 'Measurement unit', example: 'kg' })
  @IsString()
  @IsOptional()
  unit?: string;

  @ApiPropertyOptional({ description: 'Unit cost of material', example: 250.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  unitCost?: number = 0.0;

  @ApiPropertyOptional({ description: 'Total cost of this line', example: 6250.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  totalCost?: number = 0.0;
}

export class CreateProductionOrderDto {
  @ApiProperty({ description: 'Finished Product UUID' })
  @IsUUID()
  @IsNotEmpty()
  finishedProductId!: string;

  @ApiPropertyOptional({ description: 'Finished Product Name' })
  @IsString()
  @IsOptional()
  finishedProductName?: string;

  @ApiPropertyOptional({ description: 'Finished Product Code' })
  @IsString()
  @IsOptional()
  finishedProductCode?: string;

  @ApiPropertyOptional({ description: 'Unit of output', example: 'PCS' })
  @IsString()
  @IsOptional()
  unit?: string;

  @ApiProperty({ description: 'Planned production quantity', example: 10.0 })
  @IsNumber()
  @Min(0.0001)
  @IsNotEmpty()
  plannedQuantity!: number;

  @ApiPropertyOptional({ description: 'Actual produced quantity', example: 10.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  actualQuantityProduced?: number = 0.0;

  @ApiPropertyOptional({ type: [ProductionRawMaterialUsageDto], description: 'Raw materials consumed' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ProductionRawMaterialUsageDto)
  @IsOptional()
  rawMaterialsUsed?: ProductionRawMaterialUsageDto[] = [];

  @ApiPropertyOptional({ type: [ProductionRawMaterialUsageDto], description: 'Raw materials consumed (alias)' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ProductionRawMaterialUsageDto)
  @IsOptional()
  rawMaterials?: ProductionRawMaterialUsageDto[];

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  rawMaterialCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  labourCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  otherExpenses?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  totalProductionCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  costPerUnit?: number = 0.0;

  @ApiPropertyOptional({ description: 'Production Date (ISO string)' })
  @IsString()
  @IsOptional()
  productionDate?: string;

  @ApiPropertyOptional({
    enum: ProductionStatusEnum,
    default: ProductionStatusEnum.completed,
  })
  @IsEnum(ProductionStatusEnum)
  @IsOptional()
  status?: ProductionStatusEnum = ProductionStatusEnum.completed;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  salesOrderId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  salesOrderNumber?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  projectName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional({ description: 'Allow negative stock override', default: false })
  @IsBoolean()
  @IsOptional()
  overrideStockValidation?: boolean = false;
}

export class CompleteProductionOrderDto {
  @ApiProperty({ description: 'Actual produced quantity', example: 20.0 })
  @IsNumber()
  @Min(0.0001)
  @IsNotEmpty()
  actualQuantityProduced!: number;

  @ApiProperty({ type: [ProductionRawMaterialUsageDto], description: 'Raw materials consumed' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ProductionRawMaterialUsageDto)
  @IsNotEmpty()
  rawMaterialsUsed!: ProductionRawMaterialUsageDto[];

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  rawMaterialCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  labourCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  otherExpenses?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  totalProductionCost?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  costPerUnit?: number = 0.0;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional({ description: 'Allow negative stock override', default: false })
  @IsBoolean()
  @IsOptional()
  overrideStockValidation?: boolean = false;
}

export class CancelProductionOrderDto {
  @ApiProperty({ description: 'Reason for cancellation and soft delete' })
  @IsString()
  @IsNotEmpty()
  reason!: string;
}

export class UpdateProductionOrderStatusDto {
  @ApiProperty({ enum: ProductionStatusEnum, description: 'New order status' })
  @IsEnum(ProductionStatusEnum)
  @IsNotEmpty()
  status!: ProductionStatusEnum;

  @ApiPropertyOptional({ description: 'Actual quantity produced upon completion' })
  @IsNumber()
  @Min(0)
  @IsOptional()
  actualQuantityProduced?: number;

  @ApiPropertyOptional({ description: 'Reason or notes for status update' })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiPropertyOptional({ description: 'Allow negative stock override', default: false })
  @IsBoolean()
  @IsOptional()
  overrideStockValidation?: boolean = false;
}

