import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

export class CreatePaymentModeDto {
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

  @IsBoolean()
  @IsOptional()
  requiresReference?: boolean;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class UpdatePaymentModeDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsBoolean()
  @IsOptional()
  requiresReference?: boolean;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class UpdatePaymentModeStatusDto {
  @IsBoolean()
  @IsNotEmpty()
  isActive!: boolean;
}
