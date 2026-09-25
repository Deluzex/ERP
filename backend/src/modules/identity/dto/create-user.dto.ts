import {
  IsArray,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class CreateUserDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsEmail()
  @IsNotEmpty()
  email!: string;

  @IsString()
  @IsNotEmpty()
  mobile!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsString()
  @IsNotEmpty()
  roleId!: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  assignedRoleIds?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  branchIds?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  stockLocationIds?: string[];

  @IsString()
  @IsOptional()
  avatarUrl?: string;
}
