import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ReportQueryDto {
  @ApiPropertyOptional({
    description: 'Start date filter (ISO8601)',
  })
  @IsString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({
    description: 'End date filter (ISO8601)',
  })
  @IsString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({
    description: 'Filter by specific party (Customer, Vendor, Architect, Dealer)',
  })
  @IsString()
  @IsOptional()
  partyId?: string;

  @ApiPropertyOptional({
    description: 'Filter by specific project UUID',
  })
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiPropertyOptional({
    description: 'Filter by item category UUID or name',
  })
  @IsString()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional({
    description: 'Export format: json, pdf, excel, csv',
    default: 'json',
  })
  @IsString()
  @IsOptional()
  exportFormat?: string;
}
