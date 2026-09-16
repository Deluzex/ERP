import { Global, Module } from '@nestjs/common';
import { AppLogger } from '../logging/logger.service';
import { DatabasePool } from './connection';
import { UnitOfWork } from './unit-of-work';

@Global()
@Module({
  providers: [DatabasePool, UnitOfWork, AppLogger],
  exports: [DatabasePool, UnitOfWork],
})
export class DatabaseModule {}
