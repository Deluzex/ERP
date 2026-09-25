import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum PartyType {
  CUSTOMER = 'customer',
  DEALER = 'dealer',
  ARCHITECT = 'architect',
}

export enum SalesDocumentType {
  QUOTATION = 'quotation',
  PROFORMA_INVOICE = 'proformaInvoice',
  SALES_ORDER = 'salesOrder',
  DELIVERY = 'delivery',
  INVOICE = 'invoice',
  SALES_RETURN = 'salesReturn',
}

export enum PaymentMode {
  CASH = 'cash',
  BANK_TRANSFER = 'bankTransfer',
  CHEQUE = 'cheque',
  UPI = 'upi',
  CREDIT = 'credit',
  CREDIT_NOTE = 'creditNote',
}

export enum ReturnCondition {
  RESALABLE = 'resalable',
  DAMAGED = 'damaged',
  SCRAP = 'scrap',
  GOOD_CONDITION = 'goodCondition',
  REPAIRABLE = 'repairable',
}

export enum ReturnFinancialAction {
  CREDIT_NOTE = 'creditNote',
  REFUND = 'refund',
  ADJUST_OUTSTANDING = 'adjustOutstanding',
}

export class SaleLineItemDto {
  @ApiProperty()
  @IsUUID()
  finishedProductId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  finishedProductName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  finishedProductCode?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  productDescription?: string;

  @ApiProperty()
  @IsNumber()
  @Min(0.0001)
  quantity!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  rate?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  discountAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  gstPercent?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  returnCondition?: string;
}

export class CreateQuotationDto {
  @ApiProperty({ enum: PartyType })
  @IsEnum(PartyType)
  partyType!: PartyType;

  @ApiProperty()
  @IsUUID()
  partyId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  architectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  projectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  salesExecutive?: string;

  @ApiPropertyOptional({ default: 30 })
  @IsOptional()
  @IsNumber()
  validDays?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isInterStateTax?: boolean;

  @ApiPropertyOptional({ default: false, description: 'Save as draft instead of marking sent to client' })
  @IsOptional()
  @IsBoolean()
  isDraft?: boolean;

  @ApiProperty({ type: [SaleLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SaleLineItemDto)
  items!: SaleLineItemDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  termsAndConditions?: string;
}

export class CreateQuotationRevisionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  discountAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  termsAndConditions?: string;

  @ApiPropertyOptional({ default: false, description: 'Save revision as draft instead of marking sent to client' })
  @IsOptional()
  @IsBoolean()
  isDraft?: boolean;

  @ApiProperty({ type: [SaleLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SaleLineItemDto)
  items!: SaleLineItemDto[];
}

export class UpdateQuotationStatusDto {
  @ApiProperty()
  @IsString()
  status!: string;
}

export class RecordAdvancePaymentDto {
  @ApiProperty()
  @IsNumber()
  @Min(0.01)
  amount!: number;

  @ApiProperty({ enum: PaymentMode, default: PaymentMode.BANK_TRANSFER })
  @IsEnum(PaymentMode)
  paymentMode!: PaymentMode;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  transactionReference?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class CreateSalesOrderDto {
  @ApiProperty({ enum: PartyType })
  @IsEnum(PartyType)
  partyType!: PartyType;

  @ApiProperty()
  @IsUUID()
  partyId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  architectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  projectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  salesExecutive?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  deliveryDate?: string;

  @ApiPropertyOptional({ enum: PaymentMode, default: PaymentMode.BANK_TRANSFER })
  @IsOptional()
  @IsEnum(PaymentMode)
  paymentMode?: PaymentMode;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isInterStateTax?: boolean;

  @ApiProperty({ type: [SaleLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SaleLineItemDto)
  items!: SaleLineItemDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateSalesOrderStatusDto {
  @ApiProperty()
  @IsString()
  status!: string;
}

export class DeliveryItemDto {
  @ApiProperty()
  @IsUUID()
  finishedProductId!: string;

  @ApiProperty()
  @IsNumber()
  @Min(0.0001)
  quantity!: number;
}

export class CreateDeliveryDto {
  @ApiProperty()
  @IsUUID()
  salesOrderId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  vehicleNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  driverContact?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courierName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  trackingNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  expectedDeliveryDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  dispatchNotes?: string;

  @ApiProperty({ type: [DeliveryItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DeliveryItemDto)
  items!: DeliveryItemDto[];
}

export class UpdateDeliveryTrackingDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courierName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  trackingNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  vehicleNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  driverContact?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  dispatchNotes?: string;
}

export class CreateInvoiceFromDeliveryDto {
  @ApiProperty()
  @IsUUID()
  deliveryId!: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber()
  discountAmount?: number;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber()
  initialPaidAmount?: number;

  @ApiPropertyOptional({ enum: PaymentMode, default: PaymentMode.BANK_TRANSFER })
  @IsOptional()
  @IsEnum(PaymentMode)
  paymentMode?: PaymentMode;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class CreateDirectSaleDto {
  @ApiProperty({ enum: PartyType })
  @IsEnum(PartyType)
  partyType!: PartyType;

  @ApiProperty()
  @IsUUID()
  partyId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  architectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  projectId?: string;

  @ApiProperty({ type: [SaleLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SaleLineItemDto)
  items!: SaleLineItemDto[];

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsNumber()
  paidAmount?: number;

  @ApiPropertyOptional({ enum: PaymentMode, default: PaymentMode.UPI })
  @IsOptional()
  @IsEnum(PaymentMode)
  paymentMode?: PaymentMode;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isInterStateTax?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class RecordInvoicePaymentDto {
  @ApiProperty()
  @IsNumber()
  @Min(0.01)
  amount!: number;

  @ApiProperty({ enum: PaymentMode, default: PaymentMode.BANK_TRANSFER })
  @IsEnum(PaymentMode)
  paymentMode!: PaymentMode;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  transactionReference?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class CreateSalesReturnDto {
  @ApiProperty()
  @IsUUID()
  originalInvoiceId!: string;

  @ApiProperty()
  @IsString()
  returnReason!: string;

  @ApiPropertyOptional({ enum: ReturnCondition, default: ReturnCondition.RESALABLE })
  @IsOptional()
  @IsEnum(ReturnCondition)
  condition?: ReturnCondition;

  @ApiPropertyOptional({ enum: ReturnFinancialAction, default: ReturnFinancialAction.ADJUST_OUTSTANDING })
  @IsOptional()
  @IsEnum(ReturnFinancialAction)
  financialAction?: ReturnFinancialAction;

  @ApiProperty({ type: [SaleLineItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SaleLineItemDto)
  items!: SaleLineItemDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class DisburseRefundDto {
  @ApiProperty()
  @IsNumber()
  @Min(0.01)
  amount!: number;

  @ApiProperty({ enum: PaymentMode, default: PaymentMode.BANK_TRANSFER })
  @IsEnum(PaymentMode)
  paymentMode!: PaymentMode;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  transactionReference?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class SalesQueryDto {
  @ApiPropertyOptional({ enum: SalesDocumentType })
  @IsOptional()
  @IsString()
  documentType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  partyId?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  limit?: number = 50;
}
