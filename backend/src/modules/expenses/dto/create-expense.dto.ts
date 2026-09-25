import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
} from 'class-validator';

export const EXPENSE_CATEGORIES = [
  'transportation',
  'courier',
  'fuel',
  'labour',
  'electricity',
  'maintenance',
  'officeExpense',
  'productionExpense',
  'projectExpense',
  'other',
] as const;

export class CreateExpenseDto {
  @ApiProperty({
    description: 'Title or name of the expense voucher',
    example: 'Site Freight & Dedicated Crane Delivery',
  })
  @IsString()
  @IsNotEmpty()
  expenseName!: string;

  @ApiProperty({
    description: 'Expense category',
    enum: EXPENSE_CATEGORIES,
    example: 'transportation',
  })
  @IsString()
  @IsNotEmpty()
  @IsIn(EXPENSE_CATEGORIES)
  category!: string;

  @ApiProperty({
    description: 'Expense amount in INR',
    example: 14500.0,
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount!: number;

  @ApiPropertyOptional({
    description: 'Date of the expense (ISO8601 string)',
  })
  @IsString()
  @IsOptional()
  expenseDate?: string;

  @ApiProperty({
    description: 'Name of the employee/officer who paid the amount',
    example: 'Alex Sterling',
  })
  @IsString()
  @IsNotEmpty()
  paidBy!: string;

  @ApiProperty({
    description: 'Mode of payment (Cash, Bank Transfer, UPI, Cheque, Card)',
    example: 'Bank Transfer',
  })
  @IsString()
  @IsNotEmpty()
  paymentMethod!: string;

  @ApiPropertyOptional({
    description: 'Payee or vendor name',
    example: 'QuickMove Logistics LLP',
  })
  @IsString()
  @IsOptional()
  vendorPayee?: string;

  @ApiPropertyOptional({
    description: 'Linked project UUID if site-specific expense',
  })
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({
    description: 'Linked project name',
  })
  @IsString()
  @IsOptional()
  projectName?: string;

  @ApiPropertyOptional({
    description: 'Linked purchase order UUID if freight/customs on purchase',
  })
  @IsString()
  @IsOptional()
  purchaseId?: string;

  @ApiPropertyOptional({
    description: 'Linked purchase number',
  })
  @IsString()
  @IsOptional()
  purchaseNumber?: string;

  @ApiPropertyOptional({
    description: 'Linked production work order UUID if job-work/direct labour',
  })
  @IsString()
  @IsOptional()
  productionId?: string;

  @ApiPropertyOptional({
    description: 'Linked production order number',
  })
  @IsString()
  @IsOptional()
  productionNumber?: string;

  @ApiPropertyOptional({
    description: 'Bill reference or LR number',
    example: 'QM/LR/9924',
  })
  @IsString()
  @IsOptional()
  expenseReference?: string;

  @ApiPropertyOptional({
    description: 'Detailed description / scope',
  })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({
    description: 'Uploaded bill/receipt filename or url',
  })
  @IsString()
  @IsOptional()
  receiptAttachmentName?: string;

  @ApiPropertyOptional({
    description: 'Settlement status',
    enum: ['paid', 'partial', 'pending'],
    default: 'paid',
  })
  @IsString()
  @IsOptional()
  @IsIn(['paid', 'partial', 'pending'])
  paymentStatus?: string;
}
