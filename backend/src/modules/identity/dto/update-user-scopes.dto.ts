import { IsArray, IsOptional, IsString } from 'class-validator';

export class UpdateUserScopesDto {
  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  branchIds?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  stockLocationIds?: string[];
}
