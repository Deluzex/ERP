import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from 'class-validator';

export class CreatePaymentDto {
  @ApiProperty({
    description: 'Type of payment transaction',
    enum: ['customerPayment', 'dealerPayment', 'vendorPayment', 'commissionPayment'],
    example: 'customerPayment',
  })
  @IsString()
  @IsNotEmpty()
  @IsIn(['customerPayment', 'dealerPayment', 'vendorPayment', 'commissionPayment'])
  paymentType!: string;

  @ApiProperty({
    description: 'Unique UUID of the party (Customer, Dealer, Vendor, Architect)',
    example: '00000000-0000-0000-0000-000000000001',
  })
  @IsString()
  @IsNotEmpty()
  partyId!: string;

  @ApiProperty({
    description: 'Display name of the party',
    example: 'Oberoi Sky City Residences',
  })
  @IsString()
  @IsNotEmpty()
  partyName!: string;

  @ApiPropertyOptional({
    description: 'UUID of the linked Tax Invoice, Purchase Order, or Commission',
  })
  @IsString()
  @IsOptional()
  referenceDocumentId?: string;

  @ApiPropertyOptional({
    description: 'Document number of the reference (e.g., INV-2026-001)',
  })
  @IsString()
  @IsOptional()
  referenceDocumentNumber?: string;

  @ApiProperty({
    description: 'Payment voucher amount (in INR)',
    example: 50000.0,
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount!: number;

  @ApiProperty({
    description: 'Mode of payment',
    enum: ['cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote', 'card'],
    example: 'bankTransfer',
  })
  @IsString()
  @IsNotEmpty()
  @IsIn(['cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote', 'card'])
  paymentMode!: string;

  @ApiPropertyOptional({
    description: 'Transaction date (ISO8601 string)',
  })
  @IsString()
  @IsOptional()
  paymentDate?: string;

  @ApiPropertyOptional({
    description: 'UTR / Cheque number / Transaction reference',
    example: 'NEFT-HDFC-994821',
  })
  @IsString()
  @IsOptional()
  transactionReference?: string;

  @ApiPropertyOptional({
    description: 'Optional notes / remarks',
  })
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional({
    description: 'Flag indicating whether this payment fully settles the document',
    default: false,
  })
  @IsBoolean()
  @IsOptional()
  isFullPayment?: boolean;

  @ApiPropertyOptional({
    description: 'Total document amount before this payment',
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsOptional()
  totalDocumentAmount?: number;

  @ApiPropertyOptional({
    description: 'Remaining amount after this payment',
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsOptional()
  remainingAmount?: number;

  @ApiPropertyOptional({
    description: 'Optional linked architectural project UUID',
  })
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({
    description: 'Optional linked architectural project name',
  })
  @IsString()
  @IsOptional()
  projectName?: string;
}
