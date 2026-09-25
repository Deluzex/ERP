import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class PaymentQueryDto {
  @ApiPropertyOptional({
    description: 'Filter by payment type',
    enum: ['customerPayment', 'dealerPayment', 'vendorPayment', 'commissionPayment'],
  })
  @IsString()
  @IsOptional()
  paymentType?: string;

  @ApiPropertyOptional({
    description: 'Filter by party UUID',
  })
  @IsString()
  @IsOptional()
  partyId?: string;

  @ApiPropertyOptional({
    description: 'Filter by payment mode',
  })
  @IsString()
  @IsOptional()
  paymentMode?: string;

  @ApiPropertyOptional({
    description: 'Filter by reference document ID',
  })
  @IsString()
  @IsOptional()
  referenceDocumentId?: string;

  @ApiPropertyOptional({
    description: 'Filter by project ID',
  })
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({
    description: 'Filter records from start date (ISO8601)',
  })
  @IsString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({
    description: 'Filter records up to end date (ISO8601)',
  })
  @IsString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({
    description: 'Search string across payment number, party name, or notes',
  })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page: number = 1;

  @ApiPropertyOptional({ default: 50, minimum: 1, maximum: 200 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  @IsOptional()
  limit: number = 50;
}

export class CommissionQueryDto {
  @ApiPropertyOptional({
    description: 'Filter by architect UUID',
  })
  @IsString()
  @IsOptional()
  architectId?: string;

  @ApiPropertyOptional({
    description: 'Filter by commission status',
    enum: ['generated', 'approved', 'paid', 'rejected'],
  })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiPropertyOptional({
    description: 'Search string across commission number, architect name, or invoice number',
  })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page: number = 1;

  @ApiPropertyOptional({ default: 50, minimum: 1, maximum: 200 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  @IsOptional()
  limit: number = 50;
}

export class RejectCommissionDto {
  @ApiPropertyOptional({
    description: 'Mandatory reason explaining why the commission is rejected',
    example: 'Order returned by client before completion',
  })
  @IsString()
  @IsOptional()
  reason?: string;
}

export class DisburseCommissionDto {
  @ApiPropertyOptional({
    description: 'Payment mode for disbursal',
    enum: ['bankTransfer', 'cheque', 'upi', 'cash', 'creditNote'],
    default: 'bankTransfer',
  })
  @IsString()
  @IsOptional()
  paymentMode: string = 'bankTransfer';

  @ApiPropertyOptional({
    description: 'Payment reference UTR / Cheque No',
    example: 'NEFT-AXIS-883921',
  })
  @IsString()
  @IsOptional()
  transactionReference?: string;

  @ApiPropertyOptional({
    description: 'Notes on disbursal',
  })
  @IsString()
  @IsOptional()
  notes?: string;
}
