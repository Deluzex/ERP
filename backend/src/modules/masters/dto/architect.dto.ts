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

  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsNotEmpty()
  address!: string;

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

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultCommissionRate?: number;

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

  @IsString()
  @IsOptional()
  gstNumber?: string;

  @IsString()
  @IsOptional()
  address?: string;

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

  @IsNumber()
  @Min(0)
  @IsOptional()
  defaultCommissionRate?: number;

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
