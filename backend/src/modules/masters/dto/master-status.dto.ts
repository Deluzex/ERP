import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class UpdateMasterStatusDto {
  @ApiProperty({
    description: 'Target activation status (true = active, false = inactive)',
    example: false,
  })
  @IsBoolean()
  isActive!: boolean;
}

