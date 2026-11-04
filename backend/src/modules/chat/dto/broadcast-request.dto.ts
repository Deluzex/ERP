import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class BroadcastRecipientDto {
  @ApiProperty({ description: 'User ID' })
  @IsString()
  @IsNotEmpty()
  userId!: string;

  @ApiProperty({ description: 'Recipient Name' })
  @IsString()
  @IsNotEmpty()
  name!: string;

  @ApiPropertyOptional({ description: 'Recipient Phone Number' })
  @IsString()
  @IsOptional()
  phone?: string;
}

export class BroadcastRequestDto {
  @ApiProperty({ type: [BroadcastRecipientDto], description: 'List of recipients' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BroadcastRecipientDto)
  recipients!: BroadcastRecipientDto[];

  @ApiProperty({ description: 'Subject of the broadcast', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  subject!: string;

  @ApiProperty({ description: 'Message body', maxLength: 1000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  message!: string;

  @ApiPropertyOptional({ description: 'Send via WhatsApp', default: true })
  @IsBoolean()
  @IsOptional()
  sendWhatsApp?: boolean = true;

  @ApiPropertyOptional({ description: 'Send via In-App Notification', default: true })
  @IsBoolean()
  @IsOptional()
  sendInApp?: boolean = true;
}
