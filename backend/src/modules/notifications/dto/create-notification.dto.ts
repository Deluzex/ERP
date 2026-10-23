import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateNotificationDto {
  @ApiProperty({ description: 'Notification title' })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiProperty({ description: 'Notification message body' })
  @IsString()
  @IsNotEmpty()
  message!: string;

  @ApiPropertyOptional({ description: 'Notification category type', default: 'requisition' })
  @IsString()
  @IsOptional()
  notificationType?: string;

  @ApiPropertyOptional({ description: 'Target role identifier, e.g. purchase_manager, production_manager' })
  @IsString()
  @IsOptional()
  targetRole?: string;

  @ApiPropertyOptional({ description: 'Recipient user UUID' })
  @IsUUID()
  @IsOptional()
  recipientUserId?: string;

  @ApiPropertyOptional({ description: 'Recipient display name' })
  @IsString()
  @IsOptional()
  recipientName?: string;

  @ApiPropertyOptional({ description: 'Recipient email address' })
  @IsString()
  @IsOptional()
  recipientEmail?: string;

  @ApiPropertyOptional({ description: 'Source originating ERP module', default: 'sales' })
  @IsString()
  @IsOptional()
  sourceModule?: string;

  @ApiPropertyOptional({ description: 'Related entity type, e.g. sales_order' })
  @IsString()
  @IsOptional()
  relatedEntityType?: string;

  @ApiPropertyOptional({ description: 'Related entity UUID' })
  @IsUUID()
  @IsOptional()
  relatedEntityId?: string;

  @ApiPropertyOptional({ description: 'Structured metadata (salesOrderNumber, customerName, productSku, quantities, linkAction)' })
  @IsOptional()
  data?: Record<string, any>;
}
