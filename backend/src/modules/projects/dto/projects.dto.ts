import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum ProjectStatusEnum {
  planned = 'planned',
  active = 'active',
  completed = 'completed',
  closed = 'closed',
  cancelled = 'cancelled',
}

export class CreateProjectDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsOptional()
  customerId?: string;

  @IsString()
  @IsOptional()
  dealerId?: string;

  @IsString()
  @IsOptional()
  architectId?: string;

  @IsString()
  @IsOptional()
  startDate?: string;

  @IsString()
  @IsOptional()
  expectedCompletionDate?: string;

  @IsEnum(ProjectStatusEnum)
  @IsOptional()
  status?: ProjectStatusEnum;

  @IsNumber()
  @Min(0)
  @IsOptional()
  budgetAmount?: number;

  @IsString()
  @IsOptional()
  notes?: string;
}

export class UpdateProjectDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  customerId?: string;

  @IsString()
  @IsOptional()
  dealerId?: string;

  @IsString()
  @IsOptional()
  architectId?: string;

  @IsString()
  @IsOptional()
  startDate?: string;

  @IsString()
  @IsOptional()
  expectedCompletionDate?: string;

  @IsString()
  @IsOptional()
  actualCompletionDate?: string;

  @IsEnum(ProjectStatusEnum)
  @IsOptional()
  status?: ProjectStatusEnum;

  @IsNumber()
  @Min(0)
  @IsOptional()
  budgetAmount?: number;

  @IsString()
  @IsOptional()
  notes?: string;
}

export class DeleteProjectDto {
  @IsString()
  @IsNotEmpty({ message: 'A deletion reason is required for audit trail' })
  reason!: string;
}

export class ProjectQueryDto {
  @IsString()
  @IsOptional()
  search?: string;

  @IsEnum(ProjectStatusEnum)
  @IsOptional()
  status?: ProjectStatusEnum;

  @IsString()
  @IsOptional()
  customerId?: string;

  @IsString()
  @IsOptional()
  architectId?: string;

  @IsString()
  @IsOptional()
  dealerId?: string;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  @Min(1)
  page?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  @Min(1)
  limit?: number;
}
