import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { AppLogger } from '../logging/logger.service';

@Injectable()
export class DatabasePool implements OnModuleInit, OnModuleDestroy {
  private pool!: Pool;

  constructor(
    private readonly config: ConfigService,
    private readonly logger: AppLogger,
  ) {}

  onModuleInit(): void {
    const connectionString = this.config.get<string>('DATABASE_URL') ||
      'postgresql://postgres:postgres@localhost:5432/deluzex_erp';

    const min = this.config.get<number>('DATABASE_POOL_MIN') || 2;
    const max = this.config.get<number>('DATABASE_POOL_MAX') || 10;
    const isSsl =
      connectionString.includes('supabase.com') ||
      connectionString.includes('supabase.co') ||
      connectionString.includes('sslmode=require') ||
      this.config.get<string>('DATABASE_SSL') === 'true';

    this.pool = new Pool({
      connectionString,
      min,
      max,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
      ssl: isSsl ? { rejectUnauthorized: false } : undefined,
    });

    this.pool.on('error', (err) => {
      this.logger.error('Unexpected error on idle PostgreSQL client', err.stack, 'DatabasePool');
    });

    this.logger.log('PostgreSQL connection pool initialized', 'DatabasePool');
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.logger.log('PostgreSQL connection pool closed', 'DatabasePool');
    }
  }

  async getClient(): Promise<PoolClient> {
    return this.pool.connect();
  }

  async query<R extends QueryResultRow = QueryResultRow, I = unknown[]>(
    text: string,
    params?: I,
  ): Promise<QueryResult<R>> {
    const start = Date.now();
    try {
      const res = await this.pool.query<R>(text, params as unknown[]);
      const duration = Date.now() - start;
      if (duration > 1000) {
        this.logger.warn({ message: 'Slow query detected', durationMs: duration, text }, 'DatabasePool');
      }
      return res;
    } catch (err: unknown) {
      const error = err as Error;
      this.logger.error({ message: 'Database query execution failed', error: error.message, text }, error.stack, 'DatabasePool');
      throw err;
    }
  }

  async isHealthy(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }
}
