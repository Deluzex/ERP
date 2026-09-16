import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export enum AdjustmentReasonEnum {
  physicalCountMismatch = 'physicalCountMismatch',
  damagedGoods = 'damagedGoods',
  expiry = 'expiry',
  theftOrLoss = 'theftOrLoss',
  internalConsumption = 'internalConsumption',
  revaluation = 'revaluation',
  other = 'other',
}

export enum ItemTypeEnum {
  rawMaterial = 'rawMaterial',
  finishedProduct = 'finishedProduct',
}

export class CreateStockAdjustmentDto {
  @ApiProperty({ description: 'Item UUID' })
  @IsUUID()
  @IsNotEmpty()
  itemId!: string;

  @ApiProperty({
    enum: ItemTypeEnum,
    description: 'Item type: rawMaterial or finishedProduct',
  })
  @IsEnum(ItemTypeEnum)
  @IsNotEmpty()
  itemType!: ItemTypeEnum;

  @ApiProperty({
    description: 'Actual physical count verified in warehouse',
    example: 125.5,
  })
  @IsNumber()
  @IsNotEmpty()
  adjustedStockAfter!: number;

  @ApiProperty({
    enum: AdjustmentReasonEnum,
    description: 'Audited reason for variance reconciliation',
  })
  @IsEnum(AdjustmentReasonEnum)
  @IsNotEmpty()
  reason!: AdjustmentReasonEnum;

  @ApiPropertyOptional({
    description: 'Detailed remarks or observation notes',
    example: 'Damaged during relocation in Bay 3',
  })
  @IsString()
  @IsOptional()
  remarks?: string;
}
