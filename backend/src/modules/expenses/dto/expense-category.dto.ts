import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Min,
} from 'class-validator';

export class CreateExpenseCategoryDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim().toUpperCase() : value))
  @IsString()
  @IsNotEmpty()
  @Matches(/^[A-Z0-9_\-]+$/, {
    message: 'Code must be uppercase alphanumeric with optional hyphens or underscores',
  })
  code!: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  linkedKey?: string;
}

export class UpdateExpenseCategoryDto {
  @IsString()
  @IsOptional()
  name?: string;

  @Transform(({ value }) => (typeof value === 'string' ? value.trim().toUpperCase() : value))
  @IsString()
  @IsOptional()
  @Matches(/^[A-Z0-9_\-]+$/, {
    message: 'Code must be uppercase alphanumeric with optional hyphens or underscores',
  })
  code?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  linkedKey?: string;
}

export class UpdateExpenseCategoryStatusDto {
  @IsBoolean()
  @IsNotEmpty()
  isActive!: boolean;
}

export class ExpenseCategoryQueryDto {
  @IsString()
  @IsOptional()
  search?: string;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true) return true;
    if (value === 'false' || value === false) return false;
    return undefined;
  })
  isActive?: boolean;

  @IsNumber()
  @IsOptional()
  @Min(1)
  @Transform(({ value }) => (value ? parseInt(value, 10) : 1))
  page?: number;

  @IsNumber()
  @IsOptional()
  @Min(1)
  @Transform(({ value }) => (value ? parseInt(value, 10) : 25))
  limit?: number;
}
