import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export const EMAIL_MAX_LENGTH = 254;

const normalizeEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class CreateCustomerDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  mobile!: string;

  @Transform(normalizeEmail)
  @IsNotEmpty({ message: 'Please enter a valid email address.' })
  @MaxLength(EMAIL_MAX_LENGTH, { message: 'Email must be at most 254 characters.' })
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email!: string;

  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsNotEmpty()
  address!: string;

  @IsString()
  @IsOptional()
  stateCode?: string;

  @IsString()
  @IsOptional()
  linkedArchitectId?: string;

  @IsBoolean()
  @IsOptional()
  isAlsoArchitect?: boolean;
}

export class UpdateCustomerDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  mobile?: string;

  @Transform(normalizeEmail)
  @IsOptional()
  @IsNotEmpty({ message: 'Please enter a valid email address.' })
  @MaxLength(EMAIL_MAX_LENGTH, { message: 'Email must be at most 254 characters.' })
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email?: string;

  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  stateCode?: string;

  @IsString()
  @IsOptional()
  linkedArchitectId?: string;

  @IsBoolean()
  @IsOptional()
  isAlsoArchitect?: boolean;
}
