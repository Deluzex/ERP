import {
  IsBoolean,
  IsEmail,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
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
