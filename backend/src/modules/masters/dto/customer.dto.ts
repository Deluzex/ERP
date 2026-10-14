import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
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
  city?: string;

  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

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
  city?: string;

  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

  @IsString()
  @IsOptional()
  linkedArchitectId?: string;

  @IsBoolean()
  @IsOptional()
  isAlsoArchitect?: boolean;
}
