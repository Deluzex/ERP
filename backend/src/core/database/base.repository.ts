import { QueryResult, QueryResultRow } from 'pg';
import { NotFoundError } from '../errors/not-found.error';
import { DatabasePool } from './connection';
import { TransactionalContext } from './unit-of-work';

export abstract class BaseRepository<T> {
  protected abstract readonly tableName: string;

  constructor(protected readonly pool: DatabasePool) {}

  protected async query<R extends QueryResultRow = QueryResultRow>(
    text: string,
    params?: unknown[],
    tx?: TransactionalContext,
  ): Promise<QueryResult<R>> {
    if (tx) {
      return tx.query<R>(text, params);
    }
    return this.pool.query<R>(text, params);
  }

  protected abstract toDomain(row: Record<string, unknown>): T;

  async findById(id: string, tx?: TransactionalContext): Promise<T | null> {
    const res = await this.query(
      `SELECT * FROM ${this.tableName} WHERE id = $1 AND (is_deleted IS NULL OR is_deleted = false) LIMIT 1`,
      [id],
      tx,
    );
    if (res.rows.length === 0) {
      return null;
    }
    return this.toDomain(res.rows[0]);
  }

  async findByIdOrFail(id: string, tx?: TransactionalContext): Promise<T> {
    const entity = await this.findById(id, tx);
    if (!entity) {
      throw new NotFoundError(this.tableName, id);
    }
    return entity;
  }
}
