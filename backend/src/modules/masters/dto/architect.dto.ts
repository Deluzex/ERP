import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Min,
} from 'class-validator';

const emptyToUndefined = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? undefined : value;

export class CreateArchitectDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  companyName!: string;

  @IsString()
  @IsNotEmpty()
  mobile!: string;

  @IsEmail()
  @IsNotEmpty()
  email!: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsNotEmpty()
  address!: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  city?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  state?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  stateCode?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultCommissionRate?: number;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  linkedCustomerId?: string;

  @IsBoolean()
  @IsOptional()
  isAlsoCustomer?: boolean;
}

export class UpdateArchitectDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  companyName?: string;

  @IsString()
  @IsOptional()
  mobile?: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsOptional()
  address?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  city?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  state?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  stateCode?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultCommissionRate?: number;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  linkedCustomerId?: string;

  @IsBoolean()
  @IsOptional()
  isAlsoCustomer?: boolean;
}

export class LinkArchitectCustomerDto {
  @IsString()
  @IsNotEmpty()
  architectId!: string;

  @IsString()
  @IsNotEmpty()
  customerId!: string;
}
