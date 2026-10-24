import { Transform } from 'class-transformer';
import {
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

export class CreateVendorDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  contactPerson!: string;

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

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  panNumber?: string;

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
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  paymentTerms?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  creditLimit?: number;
}

export class UpdateVendorDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  contactPerson?: string;

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

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  panNumber?: string;

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
  @Matches(/^[1-9][0-9]{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
  })
  pincode?: string;

  @Transform(emptyToUndefined)
  @IsString()
  @IsOptional()
  paymentTerms?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  creditLimit?: number;
}

export class DeleteVendorDto {
  @IsString()
  @IsOptional()
  deleteReason?: string;
}
