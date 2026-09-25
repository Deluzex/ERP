import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { PurchaseItemTypeEnum, PurchaseLineItemDto } from './purchase-item.dto';

export enum PaymentModeEnum {
  cash = 'cash',
  bankTransfer = 'bankTransfer',
  cheque = 'cheque',
  upi = 'upi',
  credit = 'credit',
  creditNote = 'creditNote',
}

export enum PurchaseStatusEnum {
  draft = 'draft',
  saved = 'saved',
  partialPaid = 'partialPaid',
  paid = 'paid',
  cancelled = 'cancelled',
}

export class CreatePurchaseDto {
  @ApiProperty({ description: 'Vendor UUID' })
  @IsUUID()
  @IsNotEmpty()
  vendorId!: string;

  @ApiProperty({ description: 'Vendor name' })
  @IsString()
  @IsNotEmpty()
  vendorName!: string;

  @ApiPropertyOptional({ description: 'Vendor invoice/bill number' })
  @IsString()
  @IsOptional()
  vendorInvoiceNumber?: string;

  @ApiPropertyOptional({ description: 'Purchase bill date' })
  @IsString()
  @IsOptional()
  purchaseDate?: string;

  @ApiPropertyOptional({ description: 'Vendor tax invoice date' })
  @IsString()
  @IsOptional()
  invoiceDate?: string;

  @ApiProperty({
    enum: PurchaseItemTypeEnum,
    description: 'Purchase classification: rawMaterial or finishedProduct',
  })
  @IsEnum(PurchaseItemTypeEnum)
  @IsNotEmpty()
  purchaseType!: PurchaseItemTypeEnum;

  @ApiPropertyOptional({ description: 'Optional project link UUID' })
  @IsUUID()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({ description: 'Optional project title' })
  @IsString()
  @IsOptional()
  projectName?: string;

  @ApiProperty({
    type: [PurchaseLineItemDto],
    description: 'Line item breakdown',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PurchaseLineItemDto)
  items!: PurchaseLineItemDto[];

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  subtotalAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  discountAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  taxableAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  cgstAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  sgstAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  igstAmount?: number = 0.0;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  gstAmount?: number = 0.0;

  @ApiProperty({ description: 'Grand total payable', example: 51920.0 })
  @IsNumber()
  @Min(0)
  @IsNotEmpty()
  totalAmount!: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  paidAmount?: number = 0.0;

  @ApiPropertyOptional()
  @IsNumber()
  @Min(0)
  @IsOptional()
  pendingAmount?: number;

  @ApiPropertyOptional({
    enum: PaymentModeEnum,
    default: PaymentModeEnum.credit,
  })
  @IsEnum(PaymentModeEnum)
  @IsOptional()
  paymentMode?: PaymentModeEnum = PaymentModeEnum.credit;

  @ApiPropertyOptional({
    enum: PurchaseStatusEnum,
    default: PurchaseStatusEnum.saved,
  })
  @IsEnum(PurchaseStatusEnum)
  @IsOptional()
  status?: PurchaseStatusEnum = PurchaseStatusEnum.saved;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  attachmentUrl?: string;
}
