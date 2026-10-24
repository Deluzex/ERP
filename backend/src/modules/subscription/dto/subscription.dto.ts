import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class RenewSubscriptionDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(120)
  months?: number; // Number of months to extend (Default 12)
}

export class UpdateSubscriptionDto {
  @IsOptional()
  @IsString()
  clientName?: string;

  @IsOptional()
  @IsString()
  planName?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  warningDays?: number;

  @IsOptional()
  @IsString()
  supportPhone?: string;

  @IsOptional()
  @IsString()
  supportEmail?: string;
}

export interface SubscriptionStatusResponse {
  clientName: string;
  planName: string;
  isActive: boolean;
  isExpired: boolean;
  validFrom: string;
  validUntil: string;
  daysRemaining: number;
  showRenewalWarning: boolean;
  supportPhone: string;
  supportEmail: string;
}
