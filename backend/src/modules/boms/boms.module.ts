import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { BomsController } from './controllers/boms.controller';
import { BomsService } from './services/boms.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [BomsController],
  providers: [BomsService],
  exports: [BomsService],
})
export class BomsModule {}
