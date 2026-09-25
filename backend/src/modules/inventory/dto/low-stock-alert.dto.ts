import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';
import { ItemTypeEnum } from './stock-adjustment.dto';

export class TriggerLowStockAlertDto {
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

  @ApiPropertyOptional({ description: 'Recipient directory identifier' })
  @IsString()
  @IsOptional()
  recipientId?: string;

  @ApiPropertyOptional({ description: 'Designated recipient contact name' })
  @IsString()
  @IsOptional()
  recipientName?: string;

  @ApiPropertyOptional({ description: 'Recipient WhatsApp phone number' })
  @IsString()
  @IsOptional()
  recipientWhatsApp?: string;

  @ApiPropertyOptional({ description: 'Custom message body to broadcast' })
  @IsString()
  @IsOptional()
  customMessage?: string;
}
