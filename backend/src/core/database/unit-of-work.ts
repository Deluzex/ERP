import { Injectable } from '@nestjs/common';
import { PoolClient, QueryResult, QueryResultRow } from 'pg';
import { AppLogger } from '../logging/logger.service';
import { DatabasePool } from './connection';

export interface TransactionalContext {
  readonly client: PoolClient;
  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>>;
}

@Injectable()
export class UnitOfWork {
  constructor(
    private readonly pool: DatabasePool,
    private readonly logger: AppLogger,
  ) {}

  async runInTransaction<T>(work: (tx: TransactionalContext) => Promise<T>): Promise<T> {
    const client = await this.pool.getClient();
    const tx: TransactionalContext = {
      client,
      query: <R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]) =>
        client.query<R>(text, params),
    };

    try {
      await client.query('BEGIN');
      const result = await work(tx);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        this.logger.error('Failed to rollback transaction', (rollbackError as Error).stack, 'UnitOfWork');
      }
      throw error;
    } finally {
      client.release();
    }
  }
}
