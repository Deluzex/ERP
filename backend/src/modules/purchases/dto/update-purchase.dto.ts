import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { PaymentModeEnum, PurchaseStatusEnum } from './create-purchase.dto';
import { PurchaseItemTypeEnum, PurchaseLineItemDto } from './purchase-item.dto';

/**
 * Partial update (edit) DTO for an existing purchase order / inward bill.
 *
 * Contract notes:
 *  - All fields are optional; omitted header fields keep their current value.
 *  - `items` performs a FULL line replacement (with net stock-delta handling)
 *    and must contain at least one line when provided.
 *  - `purchase_number` and `created_by` are immutable and are therefore not
 *    accepted here (ValidationPipe `forbidNonWhitelisted` rejects them).
 *  - Status transitions are guarded in the service: cancelled bills cannot be
 *    edited; posted bills cannot revert to draft; use the dedicated
 *    `/purchases/:id/status` endpoint for cancellation.
 */
export class UpdatePurchaseDto {
  @ApiPropertyOptional({ description: 'Vendor UUID to reassign to' })
  @IsUUID()
  @IsOptional()
  vendorId?: string;

  @ApiPropertyOptional({ description: 'Vendor name override' })
  @IsString()
  @IsOptional()
  vendorName?: string;

  @ApiPropertyOptional({ description: 'Vendor invoice/bill number' })
  @IsString()
  @IsOptional()
  vendorInvoiceNumber?: string;

  @ApiPropertyOptional({ description: 'Purchase bill date (ISO8601)' })
  @IsDateString()
  @IsOptional()
  purchaseDate?: string;

  @ApiPropertyOptional({ description: 'Vendor tax invoice date (ISO8601)' })
  @IsDateString()
  @IsOptional()
  invoiceDate?: string;

  @ApiPropertyOptional({ enum: PurchaseItemTypeEnum, description: 'Purchase classification' })
  @IsEnum(PurchaseItemTypeEnum)
  @IsOptional()
  purchaseType?: PurchaseItemTypeEnum;

  @ApiPropertyOptional({ description: 'Optional project link UUID' })
  @IsUUID()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({ description: 'Optional project title' })
  @IsString()
  @IsOptional()
  projectName?: string;

  @ApiPropertyOptional({
    type: [PurchaseLineItemDto],
    description:
      'Full line item replacement with re-applied stock deltas. Omit to keep existing line items untouched.',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PurchaseLineItemDto)
  @IsOptional()
  items?: PurchaseLineItemDto[];

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  subtotalAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  discountAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  taxableAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  cgstAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  sgstAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  igstAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  gstAmount?: number;

  @ApiPropertyOptional({ description: 'Total transportation and freight charges', default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  transportationCharges?: number;

  @ApiPropertyOptional({ description: 'Grand total payable' })
  @IsNumber()
  @Min(0)
  @IsOptional()
  totalAmount?: number;

  @ApiPropertyOptional({ default: 0.0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  paidAmount?: number;

  @ApiPropertyOptional({ description: 'Optional outstanding override; defaults to total - paid' })
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
  paymentMode?: PaymentModeEnum;

  @ApiPropertyOptional({ enum: PurchaseStatusEnum, description: 'Workflow status transition (guarded)' })
  @IsEnum(PurchaseStatusEnum)
  @IsOptional()
  status?: PurchaseStatusEnum;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  attachmentUrl?: string;
}
