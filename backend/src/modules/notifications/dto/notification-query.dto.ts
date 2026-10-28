import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class NotificationQueryDto {
  @ApiPropertyOptional({ description: 'Filter only unread notifications' })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true || value === '1')
  @IsBoolean()
  unreadOnly?: boolean;

  @ApiPropertyOptional({ description: 'Filter by notification category type' })
  @IsOptional()
  @IsString()
  notificationType?: string;

  @ApiPropertyOptional({ description: 'Optional target role filter within authorized scope' })
  @IsOptional()
  @IsString()
  targetRole?: string;

  @ApiPropertyOptional({ description: 'Page number', default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @ApiPropertyOptional({ description: 'Items per page', default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 50;
}
